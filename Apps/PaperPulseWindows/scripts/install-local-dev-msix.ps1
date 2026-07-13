[CmdletBinding()]
param(
    [ValidateSet("Release")]
    [string]$Configuration = "Release"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($env:OS -ne "Windows_NT") {
    throw "This script must run on Windows."
}

$WindowsRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$Publisher = "CN=PaperPulse Development"
$FriendlyName = "PaperPulse Local Development"
$LocalStateDirectory = Join-Path $env:LOCALAPPDATA "PaperPulse\development-signing"
New-Item -ItemType Directory -Force $LocalStateDirectory | Out-Null

$Certificate = Get-ChildItem -Path "Cert:\CurrentUser\My" |
    Where-Object { $_.Subject -eq $Publisher -and $_.FriendlyName -eq $FriendlyName -and $_.HasPrivateKey -and $_.NotAfter -gt [DateTime]::Now } |
    Sort-Object NotAfter -Descending |
    Select-Object -First 1

if ($null -eq $Certificate) {
    $Certificate = New-SelfSignedCertificate `
        -Type Custom `
        -KeyUsage DigitalSignature `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3", "2.5.29.19={text}") `
        -Subject $Publisher `
        -FriendlyName $FriendlyName `
        -HashAlgorithm SHA256
}

$TrustedCertificatePath = Join-Path $LocalStateDirectory "PaperPulse.LocalDevelopment.cer"
Export-Certificate -Cert $Certificate -FilePath $TrustedCertificatePath -Force | Out-Null

$TrustedCertificateStorePath = "Cert:\LocalMachine\TrustedPeople\$($Certificate.Thumbprint)"
if (-not (Test-Path $TrustedCertificateStorePath)) {
    $Principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Run this script once from an elevated PowerShell window so the local development certificate can be trusted."
    }

    Import-Certificate -FilePath $TrustedCertificatePath -CertStoreLocation "Cert:\LocalMachine\TrustedPeople" | Out-Null
}

$WindowsKitBin = Join-Path ${env:ProgramFiles(x86)} "Windows Kits\10\bin"
$SignTool = Get-ChildItem -Path $WindowsKitBin -Recurse -File -Filter "signtool.exe" |
    Where-Object { $_.FullName -match "\\x64\\signtool\.exe$" } |
    Sort-Object FullName -Descending |
    Select-Object -First 1 -ExpandProperty FullName
if ([string]::IsNullOrWhiteSpace($SignTool)) {
    throw "signtool.exe was not found. Install the Windows SDK through the Visual Studio WinUI application development workload."
}

& (Join-Path $PSScriptRoot "package.ps1") -Configuration $Configuration

$Msix = Get-ChildItem -Path (Join-Path $WindowsRoot "BundleArtifacts") -Recurse -File -Filter "*.msix" |
    Select-Object -First 1
if ($null -eq $Msix) {
    throw "Packaging completed without producing an MSIX artifact."
}

$SignedMsix = Join-Path $Msix.DirectoryName "$($Msix.BaseName).local-dev-signed.msix"
Copy-Item -LiteralPath $Msix.FullName -Destination $SignedMsix -Force

& $SignTool sign /fd SHA256 /sha1 $Certificate.Thumbprint /v $SignedMsix
if ($LASTEXITCODE -ne 0) {
    throw "SignTool failed with exit code $LASTEXITCODE."
}

$ExistingPackage = Get-AppxPackage -Name "PaperPulse.Windows" -ErrorAction SilentlyContinue
if ($null -ne $ExistingPackage) {
    $ExistingPackage | Remove-AppxPackage
}

Add-AppxPackage -Path $SignedMsix
Write-Host "Installed local developer-signed MSIX: $SignedMsix"
