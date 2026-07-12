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

& (Join-Path $PSScriptRoot "build.ps1") -Configuration $Configuration -Platform $Platform
dotnet test $Solution --configuration $Configuration --no-build -p:Platform=$Platform
