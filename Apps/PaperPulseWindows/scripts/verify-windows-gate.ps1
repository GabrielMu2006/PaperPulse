[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("Phase0", "Phase2", "Phase3", "Phase4", "Phase5")]
    [string]$Stage,
    [switch]$F5Verified,
    [switch]$MsixInstalled,
    [switch]$PasswordVaultVerified,
    [switch]$WebView2Verified,
    [switch]$CleanVmVerified
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($env:OS -ne "Windows_NT" -or [Environment]::OSVersion.Version.Build -lt 22000) {
    throw "This validation gate requires Windows 11 (build 22000 or later)."
}

$Requirements = @{
    Phase0 = @("F5Verified", "MsixInstalled")
    Phase2 = @("PasswordVaultVerified")
    Phase3 = @("F5Verified")
    Phase4 = @("F5Verified", "WebView2Verified")
    Phase5 = @("F5Verified", "MsixInstalled", "CleanVmVerified")
}

$Evidence = @{
    F5Verified = $F5Verified.IsPresent
    MsixInstalled = $MsixInstalled.IsPresent
    PasswordVaultVerified = $PasswordVaultVerified.IsPresent
    WebView2Verified = $WebView2Verified.IsPresent
    CleanVmVerified = $CleanVmVerified.IsPresent
}

$MissingEvidence = @($Requirements[$Stage] | Where-Object { -not $Evidence[$_] })
if ($MissingEvidence.Count -gt 0) {
    throw "$Stage requires manual evidence: $($MissingEvidence -join ', '). No validation report was written."
}

$WindowsRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$RepositoryRoot = Resolve-Path (Join-Path $WindowsRoot "..\..")
$Commit = (& git -C $RepositoryRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($Commit)) {
    throw "Could not determine the current Git commit."
}

$DeveloperMode = $false
$DeveloperModeKey = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue
if ($null -ne $DeveloperModeKey) {
    $DeveloperMode = $DeveloperModeKey.AllowDevelopmentWithoutDevLicense -eq 1
}

$WebView2Runtime = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
) | ForEach-Object {
    Get-ItemProperty -Path $_ -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "*WebView2*" } |
        Select-Object -First 1 DisplayName, DisplayVersion
} | Select-Object -First 1

& (Join-Path $PSScriptRoot "build.ps1") -Configuration Debug -Platform x64
& (Join-Path $PSScriptRoot "test.ps1") -Configuration Debug -Platform x64
& (Join-Path $PSScriptRoot "package.ps1") -Configuration Release -Platform x64

$PackagePaths = @(
    Get-ChildItem -Path (Join-Path $WindowsRoot "BundleArtifacts") -Recurse -File -Filter "*.msix" |
        ForEach-Object { $_.FullName }
)
if ($PackagePaths.Count -eq 0) {
    throw "The package step succeeded without a discoverable MSIX artifact."
}

$ReportDirectory = Join-Path $RepositoryRoot "docs\development\windows-validation"
New-Item -ItemType Directory -Force $ReportDirectory | Out-Null
$ReportPath = Join-Path $ReportDirectory "$Stage-$Commit.md"
$WebView2Description = if ($null -eq $WebView2Runtime) { "Not detected" } else { "$($WebView2Runtime.DisplayName) $($WebView2Runtime.DisplayVersion)" }

@"
# PaperPulse Windows $Stage Validation

- Commit: $Commit
- Recorded at (UTC): $([DateTime]::UtcNow.ToString("o"))
- Windows: $([Environment]::OSVersion.VersionString)
- .NET SDK: $((& dotnet --version).Trim())
- Developer Mode enabled: $DeveloperMode
- WebView2 Runtime: $WebView2Description
- F5 verified: $($Evidence.F5Verified)
- Local developer-signed MSIX installed: $($Evidence.MsixInstalled)
- PasswordVault verified: $($Evidence.PasswordVaultVerified)
- WebView2 verified: $($Evidence.WebView2Verified)
- Clean VM verified: $($Evidence.CleanVmVerified)

## Commands Completed

- scripts/build.ps1 -Configuration Debug -Platform x64
- scripts/test.ps1 -Configuration Debug -Platform x64
- scripts/package.ps1 -Configuration Release -Platform x64

## Generated MSIX

$($PackagePaths | ForEach-Object { "- $_" } | Out-String)
"@ | Set-Content -Path $ReportPath -Encoding utf8

Write-Host "Windows validation report: $ReportPath"
