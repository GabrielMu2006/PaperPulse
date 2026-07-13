[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$VsWhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"

if (-not (Test-Path $VsWhere)) {
    throw "Visual Studio with the WinUI application development workload is required. Could not find vswhere.exe."
}

$MSBuildPath = @(
    & $VsWhere -latest -products * -requires Microsoft.Component.MSBuild -find "MSBuild\Current\Bin\MSBuild.exe"
) | Select-Object -First 1

if ([string]::IsNullOrWhiteSpace($MSBuildPath) -or -not (Test-Path $MSBuildPath)) {
    throw "Visual Studio MSBuild was not found. Install the WinUI application development workload."
}

Write-Output $MSBuildPath
