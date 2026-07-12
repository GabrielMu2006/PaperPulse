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

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    throw "The .NET SDK is required. Install .NET 10 SDK and the Visual Studio WinUI application development workload."
}

dotnet restore $Solution
dotnet build $Solution --configuration $Configuration --no-restore -p:Platform=$Platform
