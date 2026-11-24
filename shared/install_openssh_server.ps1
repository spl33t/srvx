# Run in an elevated PowerShell window on the REMOTE Windows server.
param(
    [string]$LoginUser,
    [string]$ReportTarget,
    [string]$ReportId
)
$ErrorActionPreference = 'Stop'
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run PowerShell as Administrator on the remote Windows server.'
}

$capability = Get-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0'
if ($capability.State -ne 'Installed') {
    $result = Add-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0'
    if ($result.RestartNeeded) {
        Write-Host 'OpenSSH installed. Restart Windows, then run this command again.'
        return
    }
}

Set-Service -Name sshd -StartupType Automatic
Start-Service -Name sshd

$rule = Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue
if ($null -eq $rule) {
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
} else {
    Enable-NetFirewallRule -Name 'OpenSSH-Server-In-TCP'
}

Write-Host ('OpenSSH Server: ' + (Get-Service sshd).Status)
if ($LoginUser -and $ReportTarget -and $ReportId) {
    $tailscale = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
    if (-not (Test-Path -LiteralPath $tailscale)) {
        $command = Get-Command tailscale.exe -ErrorAction SilentlyContinue
        if ($command) { $tailscale = $command.Source }
    }
    if (Test-Path -LiteralPath $tailscale) {
        $report = Join-Path $env:TEMP ('srvx-ssh-user-' + $ReportId + '.txt')
        [IO.File]::WriteAllText($report, $LoginUser + "`n", [Text.Encoding]::ASCII)
        try {
            & $tailscale file cp $report ($ReportTarget + ':') | Out-Host
            if ($LASTEXITCODE -eq 0) {
                Write-Host 'Username sent to srvx via Taildrop. Run srvx ssh on your PC.'
                return
            }
        } catch {
            Write-Host ('Username transfer failed: ' + $_.Exception.Message)
        }
    }
}
Write-Host ('On your PC, set USER=' + $(if ($LoginUser) { $LoginUser } else { $env:USERNAME }) + ' in config.bat, then run srvx ssh.')
