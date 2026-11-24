#Requires -Version 5.0
<#
.SYNOPSIS
  Парсер контракта метаданных команд srvx.

.DESCRIPTION
  Единственный источник описания команды — блок в начале commands\<id>.bat:

    REM @srvx id=ssh
    REM @srvx label=Терминал (SSH)
    REM @srvx aliases=
    REM @srvx desc=SSH-подключение к серверу
    REM @srvx order=10
    REM @srvx menu=1
    REM @srvx default=1
    REM @srvx needs_config=1

  Обязательные поля: label, desc.
  id по умолчанию = имя файла без .bat.
  aliases — через запятую (без пробелов или с пробелами).
  order — число сортировки (меньше = выше).
  menu/default/needs_config — 1/0, true/false, yes/no.

.PARAMETER Root
  Корень srvx (папка с srvx.bat).

.PARAMETER Action
  list | resolve | default | help | menu | validate
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Root,

    [Parameter(Mandatory = $true)]
    [ValidateSet('list', 'resolve', 'default', 'help', 'menu', 'validate', 'info')]
    [string]$Action,

    [string]$Name = '',

    [string]$Format = 'tsv'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-SrvxBool([string]$Value, [bool]$Default) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $Default }
    switch -Regex ($Value.Trim()) {
        '^(1|true|yes|on)$' { return $true }
        '^(0|false|no|off)$' { return $false }
        default { return $Default }
    }
}

function Read-SrvxCommandMeta {
    param([System.IO.FileInfo]$File)

    $idDefault = [IO.Path]::GetFileNameWithoutExtension($File.Name)
    $meta = [ordered]@{
        id           = $idDefault
        label        = $null
        aliases      = @()
        desc         = $null
        order        = 100
        menu         = $true
        default      = $false
        needs_config = $true
        file         = $File.FullName
        name         = $idDefault
        has_contract = $false
        errors       = New-Object System.Collections.Generic.List[string]
    }

    $lines = Get-Content -LiteralPath $File.FullName -Encoding UTF8 -TotalCount 60 -ErrorAction Stop
    foreach ($line in $lines) {
        if ($line -notmatch '^\s*REM\s+@srvx\s+(\w+)\s*=\s*(.*)$') { continue }
        $meta.has_contract = $true
        $key = $Matches[1].ToLowerInvariant()
        $val = $Matches[2].Trim()
        switch ($key) {
            'id' {
                if ($val) { $meta.id = $val }
            }
            'label' { $meta.label = $val }
            'aliases' {
                $meta.aliases = @(
                    $val -split ',' |
                        ForEach-Object { $_.Trim() } |
                        Where-Object { $_ }
                )
            }
            'desc' { $meta.desc = $val }
            'order' {
                $n = 100
                if ([int]::TryParse($val, [ref]$n)) { $meta.order = $n }
            }
            'menu' { $meta.menu = ConvertTo-SrvxBool $val $true }
            'default' { $meta.default = ConvertTo-SrvxBool $val $false }
            'needs_config' { $meta.needs_config = ConvertTo-SrvxBool $val $true }
            default {
                $meta.errors.Add("unknown field '$key'")
            }
        }
    }

    if (-not $meta.has_contract) {
        $meta.errors.Add('missing @srvx contract block')
    }
    if ([string]::IsNullOrWhiteSpace([string]$meta.label)) {
        $meta.errors.Add('label is required')
    }
    if ([string]::IsNullOrWhiteSpace([string]$meta.desc)) {
        $meta.errors.Add('desc is required')
    }
    if ($meta.id -ne $idDefault) {
        $meta.errors.Add("id='$($meta.id)' must match filename '$idDefault'")
    }

    $meta.valid = ($meta.errors.Count -eq 0)
    return $meta
}

function Find-SrvxCommand {
    param(
        [string]$Name,
        [object[]]$Commands,
        [string]$CommandsDir
    )
    if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
    $key = $Name.Trim().ToLowerInvariant()
    foreach ($c in $Commands) {
        if ($c.id.ToLowerInvariant() -eq $key) { return $c }
        foreach ($a in $c.aliases) {
            if ($a.ToLowerInvariant() -eq $key) { return $c }
        }
    }
    return $null
}

function Get-SrvxCommands {
    param([string]$CommandsDir)

    if (-not (Test-Path -LiteralPath $CommandsDir)) {
        throw "commands dir not found: $CommandsDir"
    }

    $items = Get-ChildItem -LiteralPath $CommandsDir -Filter '*.bat' -File |
        ForEach-Object { Read-SrvxCommandMeta -File $_ }

    # Дубликаты aliases / id
    $seen = @{}
    foreach ($c in $items) {
        if (-not $c.valid) { continue }
        $names = @($c.id) + @($c.aliases)
        foreach ($n in $names) {
            $key = $n.ToLowerInvariant()
            if ($seen.ContainsKey($key)) {
                $c.errors.Add("name/alias '$n' already used by '$($seen[$key])'")
                $c.valid = $false
            } else {
                $seen[$key] = $c.id
            }
        }
    }

    $defaults = @($items | Where-Object { $_.valid -and $_.default })
    if ($defaults.Count -gt 1) {
        foreach ($d in $defaults) {
            $d.errors.Add('multiple default=1 commands')
            $d.valid = $false
        }
    }

    return @($items | Sort-Object { $_.order }, { $_.id })
}

$commandsDir = Join-Path $Root 'commands'
$all = Get-SrvxCommands -CommandsDir $commandsDir
$valid = @($all | Where-Object { $_.valid })

switch ($Action) {
    'validate' {
        $bad = @($all | Where-Object { -not $_.valid })
        foreach ($c in $all) {
            $status = if ($c.valid) { 'OK' } else { 'FAIL' }
            $err = if ($c.errors.Count) { ($c.errors -join '; ') } else { '' }
            Write-Output ("{0}`t{1}`t{2}" -f $status, $c.name, $err)
        }
        if ($bad.Count -gt 0) { exit 1 }
        exit 0
    }

    'list' {
        foreach ($c in $valid) {
            $aliases = ($c.aliases -join ',')
            Write-Output ("{0}`t{1}`t{2}`t{3}`t{4}`t{5}`t{6}`t{7}" -f `
                $c.id, $c.label, $aliases, $c.desc, $c.order, `
                [int]$c.menu, [int]$c.default, [int]$c.needs_config)
        }
    }

    'resolve' {
        $hit = Find-SrvxCommand -Name $Name -Commands $valid -CommandsDir $commandsDir
        if (-not $hit) { exit 1 }
        Write-Output $hit.id
        exit 0
    }

    'info' {
        $hit = Find-SrvxCommand -Name $Name -Commands $valid -CommandsDir $commandsDir
        if (-not $hit) { exit 1 }
        Write-Output ("{0}`t{1}`t{2}" -f $hit.id, [int]$hit.needs_config, $hit.label)
        exit 0
    }

    'default' {
        $d = $valid | Where-Object { $_.default } | Select-Object -First 1
        if ($d) {
            Write-Output $d.id
            exit 0
        }
        if ($valid.Count -gt 0) {
            Write-Output $valid[0].id
            exit 0
        }
        exit 1
    }

    'help' {
        Write-Output ''
        Write-Output '=========================================='
        Write-Output ' srvx — Server eXecutor'
        Write-Output '=========================================='
        Write-Output ''
        Write-Output 'Использование (из папки проекта):'
        Write-Output '  srvx                 команда с default=1'
        foreach ($c in $valid) {
            $names = @($c.id) + @($c.aliases)
            $left = '  srvx ' + ($names -join ' | ')
            if ($left.Length -ge 42) { $left += '  ' } else { $left = $left.PadRight(42) }
            Write-Output ($left + $c.desc)
        }
        Write-Output '  srvx help                 эта справка'
        Write-Output ''
        Write-Output 'Конфиг читается из текущей папки:'
        Write-Output '  config.bat, password.txt, my_key'
        Write-Output ''
        $bad = @($all | Where-Object { -not $_.valid })
        if ($bad.Count -gt 0) {
            Write-Output '[!] Команды без валидного контракта @srvx:'
            foreach ($b in $bad) {
                Write-Output ("    - {0}: {1}" -f $b.name, ($b.errors -join '; '))
            }
            Write-Output ''
        }
    }

    'menu' {
        $hasConfig = $false
        $serverOs = 'linux'
        $hasSshUser = $false
        $projectDir = [string]$env:PROJECT_DIR
        if (-not [string]::IsNullOrWhiteSpace($projectDir)) {
            $cfg = Join-Path $projectDir.Trim().TrimEnd('\') 'config.bat'
            $hasConfig = Test-Path -LiteralPath $cfg
            if ($hasConfig) {
                $configLines = @(Get-Content -LiteralPath $cfg)
                if ($configLines | Where-Object { $_ -match '^\s*set\s+"?SERVER_OS=windows"?\s*$' }) { $serverOs = 'windows' }
                if ($configLines | Where-Object { $_ -match '^\s*set\s+"?USER=([^"\r\n]+)"?\s*$' }) { $hasSshUser = $true }
            }
        }
        $items = @($valid | Where-Object {
            $_.menu -and ($hasConfig -or -not $_.needs_config) -and
            (($serverOs -eq 'windows' -and
              ($_.id -in @('rdp', 'ping', 'init', 'install-openssh') -or
               ($hasSshUser -and $_.id -in @('ssh', 'vscode', 'winscp')))) -or
             ($serverOs -ne 'windows' -and $_.id -notin @('rdp', 'install-openssh')))
        })
        $i = 0
        foreach ($c in $items) {
            $i++
            Write-Output ("{0}`t{1}`t{2}" -f $i, $c.id, $c.label)
        }
    }
}
