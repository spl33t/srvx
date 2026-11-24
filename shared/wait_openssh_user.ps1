param(
    [Parameter(Mandatory = $true)][string]$ProjectDir,
    [Parameter(Mandatory = $true)][string]$Server,
    [int]$TimeoutSeconds = 1800
)
$marker = Join-Path $ProjectDir '.srvx-ssh-setup'
if (-not (Test-Path -LiteralPath $marker)) { return }
$initial = [IO.File]::ReadAllLines($marker)
if ($initial.Length -ne 2 -or $initial[0] -ne $Server) { return }
$deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
while ([DateTime]::UtcNow -lt $deadline) {
    if (-not (Test-Path -LiteralPath $marker)) { return }
    $current = [IO.File]::ReadAllLines($marker)
    if ($current.Length -ne 2 -or $current[1] -ne $initial[1]) { return }
    try {
        & (Join-Path $PSScriptRoot 'import_openssh_user.ps1') -ProjectDir $ProjectDir -Server $Server | Out-Null
    } catch {
        return
    }
    if (-not (Test-Path -LiteralPath $marker)) { return }
    Start-Sleep -Seconds 2
}
