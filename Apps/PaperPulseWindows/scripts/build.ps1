[CmdletBinding()]
param(
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Debug",
    [ValidateSet("x64")]
    [string]$Platform = "x64"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$Solution = Join-Path $Root "PaperPulse.Windows.sln"

$MSBuildPath = & (Join-Path $PSScriptRoot "Get-MSBuildPath.ps1")

& $MSBuildPath $Solution /restore /t:Build "/p:Configuration=$Configuration" "/p:Platform=$Platform"

if ($LASTEXITCODE -ne 0) {
    throw "Visual Studio MSBuild failed with exit code $LASTEXITCODE."
}
