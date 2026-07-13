[CmdletBinding()]
param(
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Debug",
    [ValidateSet("x64")]
    [string]$Platform = "x64",
    [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$CoreSolution = Join-Path $Root "PaperPulse.Core.sln"

if (-not $SkipBuild) {
    & (Join-Path $PSScriptRoot "build.ps1") -Configuration $Configuration -Platform $Platform
}

dotnet test $CoreSolution --configuration $Configuration

if ($LASTEXITCODE -ne 0) {
    throw "Portable core tests failed with exit code $LASTEXITCODE."
}
