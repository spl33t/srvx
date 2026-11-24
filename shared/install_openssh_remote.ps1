# Tries to run the local OpenSSH setup script on a Windows host over WinRM.
param(
    [Parameter(Mandatory = $true)]
    [string]$Server
)

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot 'install_openssh_server.ps1'
if (-not (Test-Path -LiteralPath $scriptPath)) { throw 'OpenSSH setup script is missing.' }

function Test-TcpPort([string]$HostName, [int]$Port) {
    $client = New-Object Net.Sockets.TcpClient
    try {
        $pending = $client.BeginConnect($HostName, $Port, $null, $null)
        if (-not $pending.AsyncWaitHandle.WaitOne(1200, $false)) { return $false }
        $client.EndConnect($pending)
        return $true
    } catch {
        return $false
    } finally {
        $client.Dispose()
    }
}

$endpoint = $null
$openEndpoints = New-Object System.Collections.Generic.List[object]
foreach ($candidate in @(@{ Port = 5986; SSL = $true }, @{ Port = 5985; SSL = $false })) {
    if (-not (Test-TcpPort $Server $candidate.Port)) { continue }
    $openEndpoints.Add($candidate)
    try {
        $null = Test-WSMan -ComputerName $Server -Port $candidate.Port -UseSSL:$candidate.SSL -ErrorAction Stop
        $endpoint = $candidate
        break
    } catch {
        Write-Host ("Port {0} is open, but anonymous WinRM check failed: {1}" -f $candidate.Port, $_.Exception.Message)
    }
}

if ($null -eq $endpoint) {
    if ($openEndpoints.Count -eq 0) {
        Write-Host 'WinRM ports 5985 and 5986 are unreachable. RDP setup is required.'
        exit 2
    }
    $endpoint = $openEndpoints[$openEndpoints.Count - 1]
    Write-Host 'A WinRM port is open. Trying authenticated access before using RDP.'
}

Write-Host ("WinRM is available on {0}:{1}. Administrator credentials are required." -f $Server, $endpoint.Port)
$credential = Get-Credential -Message ('Administrator account on ' + $Server)
if ($null -eq $credential) { exit 1 }

try {
    Invoke-Command -ComputerName $Server -Port $endpoint.Port -UseSSL:$endpoint.SSL -Credential $credential -FilePath $scriptPath -ErrorAction Stop
    Write-Host 'Remote OpenSSH setup finished.'
    exit 0
} catch {
    Write-Host ('Remote setup failed: ' + $_.Exception.Message)
    Write-Host 'For an IP address, WinRM may require HTTPS or that IP in the local TrustedHosts list.'
    exit 1
}
