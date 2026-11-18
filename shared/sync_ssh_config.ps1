# Updates %USERPROFILE%\.ssh\config from environment variables
# set by commands\vscode.bat. Kept as a script so cmd.exe quote/^
# escaping cannot split the command.
$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    [Console]::Error.WriteLine($Message)
    exit 1
}

if ([string]::IsNullOrWhiteSpace($env:SERVER)) { Fail 'SERVER is not set' }
if ([string]::IsNullOrWhiteSpace($env:SSH_HOST_ALIAS)) { Fail 'SSH_HOST_ALIAS is not set' }

$sshDir = Join-Path $env:USERPROFILE '.ssh'
if (-not (Test-Path -LiteralPath $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
}

$cfgFile = Join-Path $sshDir 'config'
$alias = $env:SSH_HOST_ALIAS.Trim()
$server = $env:SERVER.Trim()
$port = if ([string]::IsNullOrWhiteSpace($env:PORT)) { '22' } else { $env:PORT.Trim() }
if ([string]::IsNullOrWhiteSpace($env:TARGET_USER)) {
    if ([string]::IsNullOrWhiteSpace($env:USER)) { Fail 'TARGET_USER is not set' }
    $user = $env:USER.Trim()
} else {
    $user = $env:TARGET_USER.Trim()
}

$nl = [Environment]::NewLine
$start = "# BEGIN SRVX [$alias]"
$end = "# END SRVX [$alias]"
$safeAlias = $alias.Replace('"', '')
$hostLine = 'Host "' + $safeAlias + '"'

$aliveI = if ([string]::IsNullOrWhiteSpace($env:SERVER_ALIVE_INTERVAL)) { '15' } else { $env:SERVER_ALIVE_INTERVAL.Trim() }
$aliveN = if ([string]::IsNullOrWhiteSpace($env:SERVER_ALIVE_COUNT_MAX)) { '20' } else { $env:SERVER_ALIVE_COUNT_MAX.Trim() }

$useKey = ($env:SRVX_SSH_USE_KEY -eq '1')
$keyPath = $env:SSH_KEY
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add($start)
$lines.Add($hostLine)
$lines.Add('    HostName ' + $server)
$lines.Add('    User ' + $user)
$lines.Add('    Port ' + $port)

if ($useKey -and $keyPath -and (Test-Path -LiteralPath $keyPath)) {
    $key = $keyPath.Trim().Replace('\', '/')
    $lines.Add('    IdentityFile "' + $key + '"')
    $lines.Add('    IdentitiesOnly yes')
    $lines.Add('    PreferredAuthentications publickey,password')
} else {
    $lines.Add('    PreferredAuthentications password')
    $lines.Add('    PubkeyAuthentication no')
    $lines.Add('    PasswordAuthentication yes')
}

$lines.Add('    ServerAliveInterval ' + $aliveI)
$lines.Add('    ServerAliveCountMax ' + $aliveN)
$lines.Add($end)
$block = $lines -join $nl

function Remove-MarkedBlock([string]$Text, [string]$BlockStart, [string]$BlockEnd) {
    $re = '(?s)' + [regex]::Escape($BlockStart) + '.*?' + [regex]::Escape($BlockEnd) + '\r?\n?'
    return [regex]::Replace($Text, $re, '')
}

$txt = ''
if (Test-Path -LiteralPath $cfgFile) {
    $txt = [IO.File]::ReadAllText($cfgFile)
}
$txt = Remove-MarkedBlock $txt $start $end
$legacyStart = "# BEGIN VPS-CONNECT [$alias]"
$legacyEnd = "# END VPS-CONNECT [$alias]"
$txt = Remove-MarkedBlock $txt $legacyStart $legacyEnd
$txt = $txt.Trim()
if ($txt.Length -gt 0) {
    $txt = $txt + $nl + $nl + $block + $nl
} else {
    $txt = $block + $nl
}

$utf8 = New-Object System.Text.UTF8Encoding $false
[IO.File]::WriteAllText($cfgFile, $txt, $utf8)
exit 0
