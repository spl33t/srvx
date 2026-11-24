param(
    [Parameter(Mandatory = $true)][string]$ProjectDir,
    [Parameter(Mandatory = $true)][string]$Server
)
$ErrorActionPreference = 'Stop'
$marker = Join-Path $ProjectDir '.srvx-ssh-setup'
$config = Join-Path $ProjectDir 'config.bat'
if (-not (Test-Path -LiteralPath $marker) -or -not (Test-Path -LiteralPath $config)) { return }
$mutex = [System.Threading.Mutex]::new($false, 'Local\srvx-ssh-import')
try {
    if (-not $mutex.WaitOne(5000)) { return }
    try {
        if (-not (Test-Path -LiteralPath $marker)) { return }
        $lines = [IO.File]::ReadAllLines($marker)
        if ($lines.Length -ne 2 -or $lines[0] -ne $Server -or $lines[1] -notmatch '^[a-fA-F0-9]{32}$') { return }
        $report = Join-Path (Join-Path $env:USERPROFILE 'Downloads') ('srvx-ssh-user-' + $lines[1] + '.txt')
        if (-not (Test-Path -LiteralPath $report)) { return }
        $userName = [IO.File]::ReadAllText($report, [Text.Encoding]::ASCII).Trim()
        if ($userName -notmatch '^[A-Za-z0-9._-]{1,64}$') { return }
        $content = [IO.File]::ReadAllText($config, [Text.Encoding]::UTF8)
        $replacement = "set `"USER=$userName`"`r`n"
        $userLine = [regex]::new('(?im)^set[ \t]+"USER="(?:\r?\n|$)')
        $updated = $userLine.Replace($content, $replacement, 1)
        if ($updated -eq $content) { $updated = $content.TrimEnd("`r", "`n") + "`r`n" + $replacement }
        [IO.File]::WriteAllText($config, $updated, (New-Object Text.UTF8Encoding $false))
        Remove-Item -LiteralPath $marker, $report -Force
        Write-Output $userName
    } finally {
        $mutex.ReleaseMutex()
    }
} finally {
    $mutex.Dispose()
}
