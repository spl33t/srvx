param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Server,
    [Parameter(Mandatory = $true)][ValidateSet('linux', 'windows')][string]$ServerOS,
    [Parameter(Mandatory = $true)][ValidateSet('0', '1')][string]$Tailscale,
    [AllowEmptyString()][string]$User = '',
    [string]$Port = '22',
    [Parameter(Mandatory = $true)][ValidateSet('0', '1')][string]$AutoSudo
)
$ErrorActionPreference = 'Stop'
$rdpUser = ''
function Get-ExistingValue([string]$Content, [string]$Name) {
    $pattern = '(?im)^\s*set\s+"' + [regex]::Escape($Name) + '=([^"\r\n]*)"\s*$'
    $matches = [regex]::Matches($Content, $pattern)
    if ($matches.Count -eq 0) { return $null }
    return $matches[$matches.Count - 1].Groups[1].Value
}
if (Test-Path -LiteralPath $Path) {
    $existing = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
    if ((Get-ExistingValue $existing 'SERVER') -eq $Server -and
        (Get-ExistingValue $existing 'SERVER_OS') -eq $ServerOS) {
        if ($ServerOS -eq 'windows' -and -not $User) { $User = Get-ExistingValue $existing 'USER' }
        $rdpUser = Get-ExistingValue $existing 'RDP_USER'
    }
}
foreach ($value in @($Server, $User, $Port, $rdpUser)) {
    if ($value -match '["\r\n%]') { throw 'Config value contains a character that is unsafe in a batch file.' }
}
if ($Port -notmatch '^\d{1,5}$' -or [int]$Port -lt 1 -or [int]$Port -gt 65535) {
    throw 'PORT must be between 1 and 65535.'
}

$lines = @(
    '@echo off'
    'REM Настройки проекта srvx. Пустое значение означает, что параметр пока не задан.'
    'REM Запускайте srvx из папки с этим config.bat.'
    ''
    'REM ===== ПОДКЛЮЧЕНИЕ ====='
    'REM SERVER: адрес или имя удалённого компьютера.'
    'set "SERVER=' + $Server + '"'
    'REM SERVER_OS: windows или linux. Определяет доступные команды.'
    'set "SERVER_OS=' + $ServerOS + '"'
    'REM TAILSCALE: 1 проверяет, что узел доступен в tailnet; 0 отключает проверку.'
    'set "TAILSCALE=' + $Tailscale + '"'
    ''
    'REM ===== SSH / SFTP ====='
    'REM USER: учётная запись SSH. Для Linux обязательна; для Windows добавляется после настройки OpenSSH.'
    'set "USER=' + $User + '"'
    'REM PORT: порт SSH и SFTP. Для RDP не используется.'
    'set "PORT=' + $Port + '"'
    'REM SSH_KEY: приватный ключ SSH. Путь по умолчанию относительно config.bat.'
    'set "SSH_KEY=%~dp0my_key"'
    'REM PASSWORD_FILE: файл паролей SSH, SUDO и RDP. Не храните пароли в config.bat.'
    'set "PASSWORD_FILE=%~dp0password.txt"'
    'REM SERVER_ALIVE_INTERVAL: секунды между проверками SSH-соединения.'
    'set "SERVER_ALIVE_INTERVAL=15"'
    'REM SERVER_ALIVE_COUNT_MAX: число пропущенных проверок до разрыва SSH.'
    'set "SERVER_ALIVE_COUNT_MAX=20"'
    ''
    'REM ===== WINDOWS RDP ====='
    'REM RDP_USER: логин RDP. Пустое значение использует USER; RDP работает и без него.'
    'set "RDP_USER=' + $rdpUser + '"'
    ''
    'REM ===== LINUX ====='
    'REM AUTO_SUDO: 1 пытается открыть SSH-сессию с sudo; 0 оставляет обычного пользователя.'
    'set "AUTO_SUDO=' + $AutoSudo + '"'
    'REM LXQT_HTTPS_USER: логин веб-интерфейса LXQt, когда он установлен.'
    'set "LXQT_HTTPS_USER=desktop"'
)
[IO.File]::WriteAllText($Path, (($lines -join "`r`n") + "`r`n"), (New-Object Text.UTF8Encoding $false))
