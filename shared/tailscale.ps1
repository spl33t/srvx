#Requires -Version 5.0
<#
.SYNOPSIS
  Tailscale helpers for srvx init and connection checks.

.DESCRIPTION
  pick  — interactive peer menu. Writes MODE, SERVER and SERVER_OS.
  check — fail if TAILSCALE=1 but the client is down or SERVER is not an online peer.
  show  — print one status line for srvx ping.
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('pick', 'check', 'show', 'selftest')]
    [string]$Action,

    [string]$ResultFile = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Find-TailscaleExe {
    $candidates = New-Object System.Collections.Generic.List[string]
    foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        if ([string]::IsNullOrWhiteSpace($root)) { continue }
        $path = Join-Path $root 'Tailscale\tailscale.exe'
        if (Test-Path -LiteralPath $path) { $candidates.Add($path) }
    }

    $cmd = Get-Command tailscale.exe -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source -and ($cmd.Source -notmatch '\\WindowsApps\\')) {
        if ($candidates -notcontains $cmd.Source) { $candidates.Add($cmd.Source) }
    }

    if ($candidates.Count -eq 0) { return $null }
    return $candidates[0]
}

function Get-StateText([string]$State) {
    switch ($State) {
        'NeedsLogin' { return 'нужен вход' }
        'Stopped' { return 'клиент остановлен' }
        'Starting' { return 'клиент ещё запускается' }
        'NeedsMachineAuth' { return 'узел ждёт подтверждения в админке' }
        'Running' { return 'запущен' }
        default {
            if ([string]::IsNullOrWhiteSpace($State)) { return 'нет статуса' }
            return "состояние $State"
        }
    }
}

function Get-NodeWord([int]$Count) {
    $n100 = $Count % 100
    $n10 = $Count % 10
    if ($n100 -ge 11 -and $n100 -le 14) { return 'узлов' }
    if ($n10 -eq 1) { return 'узел' }
    if ($n10 -ge 2 -and $n10 -le 4) { return 'узла' }
    return 'узлов'
}

function Convert-TailscalePeer($Raw) {
    $ips = @()
    if ($Raw.PSObject.Properties.Name -contains 'TailscaleIPs' -and $Raw.TailscaleIPs) {
        $ips = @($Raw.TailscaleIPs)
    }

    $dns = ''
    if ($Raw.PSObject.Properties.Name -contains 'DNSName' -and $Raw.DNSName) {
        $dns = ([string]$Raw.DNSName).Trim().TrimEnd('.')
    }

    $v4 = ''
    foreach ($ip in $ips) {
        $text = [string]$ip
        if ($text -match '^\d{1,3}(\.\d{1,3}){3}$') {
            $v4 = $text
            break
        }
    }

    $hostName = ''
    if ($Raw.PSObject.Properties.Name -contains 'HostName' -and $Raw.HostName) {
        $hostName = [string]$Raw.HostName
    }

    $os = ''
    if ($Raw.PSObject.Properties.Name -contains 'OS' -and $Raw.OS) {
        $os = [string]$Raw.OS
    }

    $online = $false
    if ($Raw.PSObject.Properties.Name -contains 'Online') {
        $online = [bool]$Raw.Online
    }

    $server = $dns
    if ([string]::IsNullOrWhiteSpace($server)) { $server = $v4 }
    if ([string]::IsNullOrWhiteSpace($server)) { $server = $hostName }
    if ([string]::IsNullOrWhiteSpace($server)) { return $null }

    return [pscustomobject]@{
        HostName = $hostName
        OS       = $os
        Online   = $online
        Server   = $server
        IPv4     = $v4
        Dns      = $dns
    }
}

function Get-PeerObjects($Status) {
    if ($null -eq $Status -or -not ($Status.PSObject.Properties.Name -contains 'Peer') -or $null -eq $Status.Peer) {
        return ,@()
    }

    $peer = $Status.Peer
    $rawItems = New-Object System.Collections.Generic.List[object]
    if ($peer -is [System.Array]) {
        foreach ($item in $peer) { $rawItems.Add($item) }
    } elseif ($peer.PSObject.Properties.Name -contains 'HostName') {
        $rawItems.Add($peer)
    } else {
        foreach ($prop in $peer.PSObject.Properties) {
            $rawItems.Add($prop.Value)
        }
    }

    $list = New-Object System.Collections.Generic.List[object]
    foreach ($item in $rawItems) {
        if ($null -eq $item) { continue }
        $converted = Convert-TailscalePeer $item
        if ($null -ne $converted) { $list.Add($converted) }
    }
    return ,$list.ToArray()
}

function Sort-TailscalePeers($Peers) {
    $items = New-Object System.Collections.Generic.List[object]
    if ($null -ne $Peers) {
        foreach ($peer in $Peers) {
            if ($null -ne $peer) { $items.Add($peer) }
        }
    }
    $sorted = $items | Sort-Object @{ Expression = { if ($_.Online) { 0 } else { 1 } } }, @{ Expression = { if ($_.OS -eq 'linux') { 0 } else { 1 } } }, @{ Expression = { $_.HostName } }
    $out = New-Object System.Collections.Generic.List[object]
    if ($null -ne $sorted) {
        foreach ($peer in @($sorted)) {
            if ($null -ne $peer) { $out.Add($peer) }
        }
    }
    return ,$out.ToArray()
}

function Get-TailscaleStatus([string]$Exe) {
    $raw = & $Exe status --json 2>&1 | Out-String
    $start = $raw.IndexOf('{')
    $end = $raw.LastIndexOf('}')
    if ($start -lt 0 -or $end -le $start) {
        throw 'tailscale status не вернул JSON'
    }
    $json = $raw.Substring($start, $end - $start + 1)
    return ($json | ConvertFrom-Json)
}

function Find-TailscalePeer($Peers, [string]$Target) {
    if ([string]::IsNullOrWhiteSpace($Target)) { return $null }
    $wanted = $Target.Trim().TrimEnd('.').ToLowerInvariant()
    foreach ($peer in $Peers) {
        $names = @(
            ([string]$peer.HostName).Trim().TrimEnd('.').ToLowerInvariant()
            ([string]$peer.Dns).Trim().TrimEnd('.').ToLowerInvariant()
            ([string]$peer.Server).Trim().TrimEnd('.').ToLowerInvariant()
            ([string]$peer.IPv4).Trim().ToLowerInvariant()
        )
        if ($names -contains $wanted -and -not [string]::IsNullOrWhiteSpace($wanted)) {
            return $peer
        }
    }
    return $null
}

function Get-DefaultPeerIndex($Peers) {
    $onlinePeers = @($Peers | Where-Object { $_.Online })
    if ($onlinePeers.Count -ne 1) { return -1 }
    for ($i = 0; $i -lt $Peers.Count; $i++) {
        if ($Peers[$i].Server -eq $onlinePeers[0].Server -and $Peers[$i].HostName -eq $onlinePeers[0].HostName) {
            return $i
        }
    }
    return -1
}

function Assert-TailscaleReady($Status) {
    $state = ''
    if ($Status.PSObject.Properties.Name -contains 'BackendState') {
        $state = [string]$Status.BackendState
    }
    if ($state -ne 'Running') {
        throw ('Tailscale: ' + (Get-StateText $state) + '. Откройте клиент и войдите в tailnet.')
    }
}

function Write-PeerLine($Peer) {
    $state = if ($Peer.Online) { 'online' } else { 'offline' }
    $os = if ([string]::IsNullOrWhiteSpace($Peer.OS)) { '-' } else { $Peer.OS }
    $name = if ([string]::IsNullOrWhiteSpace($Peer.HostName)) { $Peer.Server } else { $Peer.HostName }
    Write-Host ('Tailscale: {0,-16} {1,-8} {2,-8} {3}' -f $name, $os, $state, $Peer.Server)
}

function Resolve-ConfiguredPeer {
    $server = [string]$env:SERVER
    if ([string]::IsNullOrWhiteSpace($server)) {
        throw 'SERVER не указан в config.bat'
    }

    $exe = Find-TailscaleExe
    if (-not $exe) {
        throw 'Tailscale не найден. Установите клиент или уберите TAILSCALE=1 из config.bat.'
    }

    $status = Get-TailscaleStatus $exe
    Assert-TailscaleReady $status
    $peers = Sort-TailscalePeers (Get-PeerObjects $status)
    $peer = Find-TailscalePeer $peers $server
    if ($null -eq $peer) {
        throw "Узел '$server' не найден в tailnet."
    }
    if (-not $peer.Online) {
        throw "Узел '$($peer.HostName)' сейчас offline."
    }
    return $peer
}

function Write-PickResult {
    param([string[]]$Lines)
    if (-not [string]::IsNullOrWhiteSpace($ResultFile)) {
        $utf8 = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllLines($ResultFile, $Lines, $utf8)
        return
    }
    foreach ($line in $Lines) {
        Write-Output $line
    }
}

function Write-SelectedPeer($Peer) {
    $server = $Peer.Server
    if ($Peer.OS -eq 'windows' -and $Peer.IPv4) { $server = $Peer.IPv4 }
    Write-PickResult @('MODE=tailscale', ('SERVER=' + $server), ('SERVER_OS=' + $Peer.OS))
}

function Invoke-Pick {
    if ([Console]::IsInputRedirected) {
        Write-PickResult @('MODE=manual')
        return
    }

    $exe = Find-TailscaleExe
    if (-not $exe) {
        Write-PickResult @('MODE=manual')
        return
    }

    try {
        $status = Get-TailscaleStatus $exe
        Assert-TailscaleReady $status
    } catch {
        Write-Host ('[!] {0}' -f $_.Exception.Message)
        Write-Host '    Адрес можно ввести вручную.'
        Write-Host ''
        Write-PickResult @('MODE=manual')
        return
    }

    $peers = Sort-TailscalePeers @((Get-PeerObjects $status) | Where-Object { $_.OS -eq 'linux' -or $_.OS -eq 'windows' })
    if ($peers.Count -eq 0) {
        Write-Host '[!] В tailnet нет узлов Windows или Linux.'
        Write-Host ''
        Write-PickResult @('MODE=manual')
        return
    }

    $shown = $peers
    $filtered = $false
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        Write-Host ''
        if ($filtered) {
            Write-Host ('Подходящие узлы Tailscale: {0}' -f $shown.Count)
        } else {
            Write-Host ('Серверы Tailscale: {0} {1}. Введите номер, часть имени или пункт ручного ввода.' -f $peers.Count, (Get-NodeWord $peers.Count))
        }

        for ($i = 0; $i -lt $shown.Count; $i++) {
            $peer = $shown[$i]
            $state = if ($peer.Online) { 'online' } else { 'offline' }
            $os = if ([string]::IsNullOrWhiteSpace($peer.OS)) { '-' } else { $peer.OS }
            $name = if ([string]::IsNullOrWhiteSpace($peer.HostName)) { $peer.Server } else { $peer.HostName }
            Write-Host ('  [{0}] {1,-16} {2,-8} {3,-8} {4}' -f ($i + 1), $name, $os, $state, $peer.Server)
        }

        $manual = $shown.Count + 1
        Write-Host ('  [{0}] Ввести адрес вручную' -f $manual)

        $defaultIndex = -1
        if (-not $filtered) {
            $defaultIndex = Get-DefaultPeerIndex $peers
        }

        $prompt = 'Номер узла Tailscale'
        if ($defaultIndex -ge 0) {
            $prompt = 'Номер узла Tailscale [Enter = {0}]' -f ($defaultIndex + 1)
        }

        $answer = Read-Host $prompt
        if ([string]::IsNullOrWhiteSpace($answer)) {
            if ($defaultIndex -ge 0) {
                Write-SelectedPeer $peers[$defaultIndex]
                return
            }
            Write-Host '[!] Укажите номер из списка или часть имени. Пустой ввод здесь ничего не выбирает.'
            $shown = $peers
            $filtered = $false
            continue
        }

        $trimmed = $answer.Trim()
        if ($trimmed -match '^\d+$') {
            $number = [int]$trimmed
            if ($number -eq $manual) {
                Write-PickResult @('MODE=manual')
                return
            }
            if ($number -ge 1 -and $number -le $shown.Count) {
                Write-SelectedPeer $shown[$number - 1]
                return
            }
            Write-Host '[!] Нет такого номера.'
            continue
        }

        $query = $trimmed.ToLowerInvariant()
        $shown = @($peers | Where-Object {
            ([string]$_.HostName).ToLowerInvariant().Contains($query) -or
            ([string]$_.Server).ToLowerInvariant().Contains($query) -or
            ([string]$_.Dns).ToLowerInvariant().Contains($query)
        })
        if ($shown.Count -eq 1) {
            Write-SelectedPeer $shown[0]
            return
        }
        if ($shown.Count -eq 0) {
            Write-Host ('[!] Нет узла по «{0}».' -f $trimmed)
            $shown = $peers
            $filtered = $false
            continue
        }
        $filtered = $true
    }

    Write-Host '[!] Не удалось выбрать узел. Введите адрес вручную.'
    Write-Host ''
    Write-PickResult @('MODE=manual')
}

function Invoke-SelfTest {
    $linuxOnline = Convert-TailscalePeer ([pscustomobject]@{
        HostName = 'mybox'; DNSName = 'mybox.tail1234.ts.net.'; OS = 'linux'; Online = $true
        TailscaleIPs = @('100.64.1.2', 'fd7a::1')
    })
    $winOnline = Convert-TailscalePeer ([pscustomobject]@{
        HostName = 'desk'; DNSName = 'desk.tail1234.ts.net.'; OS = 'windows'; Online = $true
        TailscaleIPs = @('100.64.1.3')
    })
    $linuxOffline = Convert-TailscalePeer ([pscustomobject]@{
        HostName = 'nas'; DNSName = 'nas.tail1234.ts.net.'; OS = 'linux'; Online = $false
        TailscaleIPs = @('100.64.1.4')
    })
    $ipOnly = Convert-TailscalePeer ([pscustomobject]@{
        HostName = 'noname'; DNSName = ''; OS = 'linux'; Online = $true
        TailscaleIPs = @('100.70.0.5')
    })

    $sorted = Sort-TailscalePeers @($linuxOffline, $winOnline, $linuxOnline)
    if ($sorted[0].HostName -ne 'mybox' -or $sorted[1].HostName -ne 'desk' -or $sorted[2].HostName -ne 'nas') {
        throw 'sort order mismatch'
    }
    if ((Get-DefaultPeerIndex $sorted) -ne -1) { throw 'multiple online peers must not default' }
    if ((Get-DefaultPeerIndex @($linuxOnline, $ipOnly)) -ne -1) { throw 'two online peers must not default' }
    if ((Get-DefaultPeerIndex @($winOnline)) -ne 0) { throw 'single Windows peer must default' }
    if ($linuxOnline.Server -ne 'mybox.tail1234.ts.net') { throw 'dns server name mismatch' }
    if ($ipOnly.Server -ne '100.70.0.5') { throw 'ipv4 fallback mismatch' }

    $found = Find-TailscalePeer $sorted 'MyBox'
    if ($null -eq $found -or $found.Dns -ne 'mybox.tail1234.ts.net') { throw 'short name match failed' }
    $found = Find-TailscalePeer $sorted 'mybox.tail1234.ts.net.'
    if ($null -eq $found) { throw 'fqdn match failed' }
    $found = Find-TailscalePeer @($ipOnly) '100.70.0.5'
    if ($null -eq $found) { throw 'ip match failed' }
    if ($null -ne (Find-TailscalePeer $sorted 'missing')) { throw 'missing peer matched' }

    $map = [pscustomobject]@{
        Peer = [pscustomobject]@{
            'nodekey:a' = [pscustomobject]@{ HostName = 'b'; DNSName = 'b.tail.ts.net.'; OS = 'linux'; Online = $false; TailscaleIPs = @('100.1.1.1') }
            'nodekey:b' = [pscustomobject]@{ HostName = 'a'; DNSName = 'a.tail.ts.net.'; OS = 'linux'; Online = $true; TailscaleIPs = @('100.1.1.2') }
        }
    }
    $fromMap = Sort-TailscalePeers (Get-PeerObjects $map)
    if ($fromMap.Count -ne 2 -or $fromMap[0].HostName -ne 'a') { throw 'peer map parse failed' }

    $empty = Sort-TailscalePeers (Get-PeerObjects ([pscustomobject]@{ Peer = $null }))
    if ($empty.Count -ne 0) { throw 'empty peer list mismatch' }

    Write-Output 'SELFTEST=ok'
}

switch ($Action) {
    'pick' {
        Invoke-Pick
        exit 0
    }
    'check' {
        try {
            $null = Resolve-ConfiguredPeer
            exit 0
        } catch {
            Write-Host ('[ОШИБКА] {0}' -f $_.Exception.Message)
            exit 1
        }
    }
    'show' {
        try {
            Write-PeerLine (Resolve-ConfiguredPeer)
            exit 0
        } catch {
            Write-Host ('[ОШИБКА] {0}' -f $_.Exception.Message)
            exit 1
        }
    }
    'selftest' {
        Invoke-SelfTest
        exit 0
    }
}
