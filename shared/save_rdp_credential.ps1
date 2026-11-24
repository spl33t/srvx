param(
    [Parameter(Mandatory = $true)][string]$Server,
    [Parameter(Mandatory = $true)][string]$PasswordFile,
    [string]$UserName,
    [string]$SshUser
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $PasswordFile)) { return }
if (-not $UserName) { $UserName = $env:RDP_LOGIN }
if (-not $SshUser) { $SshUser = $env:USER }

$rdpPassword = $null
$sshPassword = $null
$fallbackPassword = $null
foreach ($rawLine in [IO.File]::ReadAllLines($PasswordFile, [Text.Encoding]::UTF8)) {
    $line = $rawLine.Trim()
    if (-not $line -or $line.StartsWith('#')) { continue }
    $separator = $line.IndexOf('=')
    if ($separator -lt 0) {
        if (-not $fallbackPassword) { $fallbackPassword = $line }
        continue
    }
    $key = $line.Substring(0, $separator).Trim()
    $value = $line.Substring($separator + 1)
    if ($key -eq 'RDP' -or $key -eq 'RDP_PASSWORD') {
        if ($value -and $value -ne 'placeholder') { $rdpPassword = $value }
    } elseif ($key -eq 'SSH' -or $key -eq 'SSH_PASSWORD') {
        if ($value -and $value -ne 'placeholder') { $sshPassword = $value }
    }
}
$password = $rdpPassword
if (-not $password -and $UserName -and $SshUser -and $UserName -eq $SshUser) {
    $password = $sshPassword
}
if (-not $password) {
    $password = $fallbackPassword
}
if (-not $password -or $password -eq 'placeholder') { return }
if (-not $UserName) { throw 'RDP password is set, but USER or RDP_USER is missing in config.bat.' }
if ($Server -notmatch '^[A-Za-z0-9._-]+$') { throw 'Invalid RDP server name for Credential Manager.' }

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace Srvx {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct Credential {
        public UInt32 Flags;
        public UInt32 Type;
        [MarshalAs(UnmanagedType.LPWStr)] public string TargetName;
        [MarshalAs(UnmanagedType.LPWStr)] public string Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public UInt32 CredentialBlobSize;
        public IntPtr CredentialBlob;
        public UInt32 Persist;
        public UInt32 AttributeCount;
        public IntPtr Attributes;
        public IntPtr TargetAlias;
        [MarshalAs(UnmanagedType.LPWStr)] public string UserName;
    }
    public static class CredentialManager {
        [DllImport("advapi32.dll", EntryPoint = "CredWriteW", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern bool CredWrite(ref Credential credential, UInt32 flags);
    }
}
'@

$bytes = [Text.Encoding]::Unicode.GetBytes($password)
if ($bytes.Length -gt 2560) { throw 'RDP password is too long for Credential Manager.' }
$blob = [Runtime.InteropServices.Marshal]::AllocHGlobal($bytes.Length)
try {
    [Runtime.InteropServices.Marshal]::Copy($bytes, 0, $blob, $bytes.Length)
    $credential = New-Object Srvx.Credential
    $credential.Type = 1 # CRED_TYPE_GENERIC
    $credential.TargetName = 'TERMSRV/' + $Server
    $credential.CredentialBlobSize = $bytes.Length
    $credential.CredentialBlob = $blob
    $credential.Persist = 2 # CRED_PERSIST_LOCAL_MACHINE
    $credential.UserName = $UserName
    if (-not [Srvx.CredentialManager]::CredWrite([ref]$credential, 0)) {
        $code = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw (New-Object ComponentModel.Win32Exception($code))
    }
    Write-Host ('RDP credentials saved for ' + $Server + ' in Windows Credential Manager.')
} finally {
    [Array]::Clear($bytes, 0, $bytes.Length)
    $zero = New-Object byte[] $bytes.Length
    [Runtime.InteropServices.Marshal]::Copy($zero, 0, $blob, $zero.Length)
    [Runtime.InteropServices.Marshal]::FreeHGlobal($blob)
}
