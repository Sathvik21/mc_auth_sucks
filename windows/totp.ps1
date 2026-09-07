<#
.SYNOPSIS
  Copies a fresh TOTP (6-digit authenticator) code to the clipboard.

.DESCRIPTION
  Windows equivalent of the macOS Raycast script in this repo. Reads an
  otpauth:// URL out of Windows Credential Manager, extracts the secret,
  computes the current TOTP code in pure PowerShell (no external TOTP
  binary required), and copies it to the clipboard.

  See ../README.md for the full setup guide and security trade-offs —
  read that before using this.

.NOTES
  Setup:
    1. Get your otpauth:// URL from your MFA provider (look for
       "I want to use a different authenticator app" or
       "Can't scan the QR code?" during registration).
    2. Store it in Credential Manager (run once):

         cmdkey /generic:totp-seed /user:totp /pass:"otpauth://totp/...your-full-url..."

       Note: cmdkey does not hide the value from shell history the way
       the macOS `read -s` approach does. Consider clearing your
       PowerShell history after running this, or store the secret using
       the CredentialManager PowerShell module instead for a scripted,
       non-echoing prompt (see README).
    3. Bind this script to a hotkey with AutoHotkey (see hotkey.ahk in
       this folder) or Windows Terminal / PowerToys Run.
#>

$ErrorActionPreference = "Stop"

$CredentialTarget = "totp-seed"

# --- Retrieve the stored otpauth:// URL from Windows Credential Manager ---
Add-Type -AssemblyName System.Runtime.InteropServices

function Get-StoredCredentialPassword {
    param([string]$Target)

    $sig = @"
using System;
using System.Runtime.InteropServices;

public class CredManager {
    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool CredRead(string target, int type, int reservedFlag, out IntPtr credentialPtr);

    [DllImport("advapi32.dll", SetLastError = true)]
    public static extern void CredFree(IntPtr cred);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct CREDENTIAL {
        public int Flags;
        public int Type;
        public string TargetName;
        public string Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public int CredentialBlobSize;
        public IntPtr CredentialBlob;
        public int Persist;
        public int AttributeCount;
        public IntPtr Attributes;
        public string TargetAlias;
        public string UserName;
    }
}
"@
    if (-not ([System.Management.Automation.PSTypeName]'CredManager').Type) {
        Add-Type -TypeDefinition $sig -ErrorAction SilentlyContinue
    }

    $credPtr = [IntPtr]::Zero
    $ok = [CredManager]::CredRead($Target, 1, 0, [ref]$credPtr)
    if (-not $ok) {
        throw "No credential found for target '$Target'. Did you run cmdkey /generic:$Target ... ?"
    }

    $cred = [System.Runtime.InteropServices.Marshal]::PtrToStructure($credPtr, [type][CredManager+CREDENTIAL])
    $bytes = New-Object byte[] $cred.CredentialBlobSize
    [System.Runtime.InteropServices.Marshal]::Copy($cred.CredentialBlob, $bytes, 0, $cred.CredentialBlobSize)
    [CredManager]::CredFree($credPtr)

    return [System.Text.Encoding]::Unicode.GetString($bytes)
}

$url = Get-StoredCredentialPassword -Target $CredentialTarget

# --- Extract the secret parameter from the otpauth:// URL ---
if ($url -notmatch '[?&]secret=([^&]+)') {
    throw "Could not find a 'secret=' parameter in the stored value. Is it a valid otpauth:// URL?"
}
$secret = $matches[1]

# --- Base32 decode ---
function ConvertFrom-Base32 {
    param([string]$Base32String)

    $alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
    $Base32String = $Base32String.ToUpper().TrimEnd('=')

    $bits = ""
    foreach ($char in $Base32String.ToCharArray()) {
        $val = $alphabet.IndexOf($char)
        if ($val -lt 0) { continue }
        $bits += [Convert]::ToString($val, 2).PadLeft(5, '0')
    }

    $byteCount = [Math]::Floor($bits.Length / 8)
    $bytes = New-Object byte[] $byteCount
    for ($i = 0; $i -lt $byteCount; $i++) {
        $byteStr = $bits.Substring($i * 8, 8)
        $bytes[$i] = [Convert]::ToByte($byteStr, 2)
    }
    return $bytes
}

$keyBytes = ConvertFrom-Base32 -Base32String $secret

# --- Compute TOTP (RFC 6238), default 30s step / 6 digits ---
$timeStep = 30
$digits = 6
$unixTime = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$counter = [long][Math]::Floor($unixTime / $timeStep)

$counterBytes = [BitConverter]::GetBytes($counter)
if ([BitConverter]::IsLittleEndian) { [Array]::Reverse($counterBytes) }

$hmac = New-Object System.Security.Cryptography.HMACSHA1
$hmac.Key = $keyBytes
$hash = $hmac.ComputeHash($counterBytes)

$offset = $hash[$hash.Length - 1] -band 0x0F
$binCode = (($hash[$offset] -band 0x7F) -shl 24) -bor `
           (($hash[$offset + 1] -band 0xFF) -shl 16) -bor `
           (($hash[$offset + 2] -band 0xFF) -shl 8) -bor `
           ($hash[$offset + 3] -band 0xFF)

$otp = ($binCode % [Math]::Pow(10, $digits)).ToString().PadLeft($digits, '0')

# --- Copy to clipboard and report ---
Set-Clipboard -Value $otp
Write-Output "Copied: $otp"
