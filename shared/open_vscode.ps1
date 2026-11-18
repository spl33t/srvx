# Starts VS Code with a remote folder URI.
# URI is built here so cmd.exe never reparses percent-encoded characters.
$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    [Console]::Error.WriteLine($Message)
    exit 1
}

if ([string]::IsNullOrWhiteSpace($env:SSH_HOST_ALIAS)) { Fail 'SSH_HOST_ALIAS is not set' }
if ([string]::IsNullOrWhiteSpace($env:TARGET_PATH)) { Fail 'TARGET_PATH is not set' }

# Host is already a safe token (no :, /, @, %). Encoding it would put
# percent-signs into the URI and VS Code would glue the host onto the path.
$alias = $env:SSH_HOST_ALIAS.Trim()
$path = $env:TARGET_PATH.Trim().Replace('\', '/')
if (-not $path.StartsWith('/')) { $path = '/' + $path }
if (-not $path.EndsWith('/')) { $path = $path + '/' }
$uri = 'vscode-remote://ssh-remote+' + $alias + $path

$exe = $env:VSCODE_EXE
if ($exe -and (Test-Path -LiteralPath $exe)) {
    Start-Process -FilePath $exe -ArgumentList @('--folder-uri', $uri)
    exit 0
}

$cmd = $env:VSCODE_CMD
if ($cmd -and (Test-Path -LiteralPath $cmd)) {
    Start-Process -FilePath $env:ComSpec -ArgumentList @('/c', 'call', $cmd, '--folder-uri', $uri) -WindowStyle Hidden
    exit 0
}

Fail 'Code.exe / code.cmd not found'
