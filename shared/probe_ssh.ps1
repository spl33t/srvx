# Reads the SSH identification line without authenticating.
param(
    [Parameter(Mandatory = $true)]
    [string]$Server,

    [ValidateRange(1, 65535)]
    [int]$Port = 22
)

$ErrorActionPreference = 'Stop'
$client = New-Object System.Net.Sockets.TcpClient

try {
    $pending = $client.BeginConnect($Server, $Port, $null, $null)
    if (-not $pending.AsyncWaitHandle.WaitOne(2500, $false)) {
        throw 'время ожидания соединения истекло'
    }
    $client.EndConnect($pending)

    $stream = $client.GetStream()
    $stream.ReadTimeout = 2500
    $banner = ''
    for ($line = 0; $line -lt 5; $line++) {
        $bytes = New-Object System.Collections.Generic.List[byte]
        for ($i = 0; $i -lt 255; $i++) {
            $value = $stream.ReadByte()
            if ($value -lt 0 -or $value -eq 10) { break }
            if ($value -ne 13) { $bytes.Add([byte]$value) }
        }
        if ($bytes.Count -eq 0 -and $value -lt 0) { break }
        $text = [System.Text.Encoding]::ASCII.GetString($bytes.ToArray())
        if ($text -match '^SSH-') {
            $banner = $text
            break
        }
    }

    if ($banner -match '^SSH-2\.0-OpenSSH(?:_|$)') {
        Write-Host ("[OK] OpenSSH отвечает на {0}:{1}: {2}" -f $Server, $Port, $banner)
        exit 0
    }
    if ($banner -match '^SSH-') {
        Write-Host ("[!] SSH отвечает на {0}:{1}, но это не OpenSSH: {2}" -f $Server, $Port, $banner)
        exit 2
    }
    Write-Host ("[!] Порт {0}:{1} открыт, но приветствие SSH не получено." -f $Server, $Port)
    exit 1
} catch {
    Write-Host ("[!] OpenSSH на {0}:{1} не обнаружен: {2}" -f $Server, $Port, $_.Exception.Message)
    exit 1
} finally {
    $client.Dispose()
}
