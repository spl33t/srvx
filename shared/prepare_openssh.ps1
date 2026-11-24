# Prepares files for copying to the remote Windows desktop over RDP.
param([switch]$NoClipboard)
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'install_openssh_server.ps1'
if (-not (Test-Path -LiteralPath $source)) { throw 'OpenSSH setup script is missing.' }
$reportId = [guid]::NewGuid().ToString('N')
$reportTarget = ''
if ($env:TAILSCALE -eq '1' -and $env:SERVER -and $env:PROJECT_DIR) {
    $localTailscale = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
    if (Test-Path -LiteralPath $localTailscale) {
        $candidate = (& $localTailscale ip -4 | Select-Object -First 1).Trim()
        if ($candidate -match '^100(?:\.\d{1,3}){3}$') {
            $reportTarget = $candidate
            if (-not $NoClipboard) {
                [IO.File]::WriteAllText((Join-Path $env:PROJECT_DIR '.srvx-ssh-setup'), ($env:SERVER + "`n" + $reportId + "`n"), [Text.Encoding]::ASCII)
            }
        }
    }
}

$folder = Join-Path $env:TEMP ('srvx-openssh-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $folder | Out-Null
$suffix = [guid]::NewGuid().ToString('N').Substring(0, 8)
$installerName = "srvx-install-openssh-$suffix.ps1"
$launcherName = "srvx-install-openssh-$suffix.cmd"
$readmeName = "srvx-open-me-$suffix.txt"
$installer = Join-Path $folder $installerName
$launcher = Join-Path $folder $launcherName
$readme = Join-Path $folder $readmeName
Copy-Item -LiteralPath $source -Destination $installer

$cmd = @'
@echo off
set "SCRIPT=%~dp0__INSTALLER__"
set "SRVX_REPORT_TARGET=__REPORT_TARGET__"
set "SRVX_REPORT_ID=__REPORT_ID__"
powershell.exe -NoProfile -Command "Start-Process -FilePath powershell.exe -Verb RunAs -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -NoExit -File ' + [char]34 + $env:SCRIPT + [char]34 + ' -LoginUser ' + [char]34 + $env:USERNAME + [char]34 + ' -ReportTarget ' + [char]34 + $env:SRVX_REPORT_TARGET + [char]34 + ' -ReportId ' + [char]34 + $env:SRVX_REPORT_ID + [char]34)"
if errorlevel 1 pause
'@
$cmd = $cmd.Replace('__INSTALLER__', $installerName)
$cmd = $cmd.Replace('__REPORT_TARGET__', $reportTarget).Replace('__REPORT_ID__', $reportId)
[IO.File]::WriteAllText($launcher, ($cmd.Trim() -replace "`r?`n", "`r`n") + "`r`n", [Text.Encoding]::ASCII)

$instructions = @'
УСТАНОВКА OPENSSH НА УДАЛЁННОЙ WINDOWS

1. Дважды щёлкните __LAUNCHER__.
2. Подтвердите запрос прав администратора (UAC).
3. Дождитесь строки OpenSSH Server: Running в окне PowerShell.
4. Если потребуется перезагрузка, перезагрузите компьютер и запустите файл ещё раз.
5. Вернитесь на свой компьютер и запустите srvx ssh. Если обратная передача имени через Taildrop не сработала, добавьте USER из окна PowerShell в config.bat.

Файлы .cmd и .ps1 должны находиться в одной папке.
'@
$instructions = $instructions.Replace('__LAUNCHER__', $launcherName)
[IO.File]::WriteAllText($readme, $instructions.Trim() + "`r`n", (New-Object Text.UTF8Encoding $true))

$script = [IO.File]::ReadAllText($source, [Text.Encoding]::UTF8)
$paste = "& {`r`n" + $script.Trim() + "`r`n}"
Write-Host ('Setup files: ' + $folder)
Write-Host '===== SCRIPT FOR REMOTE ADMIN POWERSHELL ====='
Write-Host $paste
Write-Host '===== END OF SCRIPT ====='
if ($NoClipboard) { exit 0 }

if ($reportTarget) {
    $watcher = Join-Path $PSScriptRoot 'wait_openssh_user.ps1'
    $arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $watcher + '" -ProjectDir "' + $env:PROJECT_DIR + '" -Server "' + $env:SERVER + '"'
    Start-Process -FilePath powershell.exe -ArgumentList $arguments -WindowStyle Hidden | Out-Null
    Write-Host 'srvx will add USER to config.bat automatically after the remote script sends it back.'
}

$clipboardExitCode = 5
try {
    Add-Type -AssemblyName System.Windows.Forms
    $files = New-Object System.Collections.Specialized.StringCollection
    $files.Add($launcher) | Out-Null
    $files.Add($installer) | Out-Null
    $files.Add($readme) | Out-Null
    [System.Windows.Forms.Clipboard]::SetFileDropList($files)
    Write-Host 'Setup files copied to clipboard. Paste them onto the remote desktop.'
    $clipboardExitCode = 0
} catch {
    Write-Host ('File clipboard unavailable: ' + $_.Exception.Message)
    try {
        Set-Clipboard -Value $paste
        Write-Host 'Script text copied to clipboard instead.'
        $clipboardExitCode = 2
    } catch {
        Write-Host 'Clipboard unavailable. Copy the printed script manually.'
    }
}

if ($env:TAILSCALE -eq '1' -and $env:SERVER) {
    $desktop = '\\' + $env:SERVER + '\C$\Users\Public\Desktop'
    try {
        if (Test-Path -LiteralPath $desktop) {
            Copy-Item -LiteralPath $launcher, $installer, $readme -Destination $desktop -ErrorAction Stop
            Write-Host 'Setup files copied to the remote Public Desktop over SMB.'
            exit 4
        }
    } catch {
        Write-Host ('Remote Desktop copy over SMB failed: ' + $_.Exception.Message)
    }

    $tailscale = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
    if (-not (Test-Path -LiteralPath $tailscale)) {
        $command = Get-Command tailscale.exe -ErrorAction SilentlyContinue
        if ($command) { $tailscale = $command.Source }
    }
    if (Test-Path -LiteralPath $tailscale) {
        try {
            & $tailscale file cp $launcher $installer $readme ($env:SERVER + ':') | Out-Host
            if ($LASTEXITCODE -eq 0) {
                Write-Host 'Taildrop sent setup files to Downloads on the remote Windows PC.'
                exit 3
            }
            Write-Host ('Taildrop transfer failed (exit code ' + $LASTEXITCODE + ').')
        } catch {
            Write-Host ('Taildrop transfer failed: ' + $_.Exception.Message)
        }
    }
}
exit $clipboardExitCode
