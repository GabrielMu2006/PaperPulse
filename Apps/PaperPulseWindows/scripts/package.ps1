[CmdletBinding()]
param(
    [ValidateSet("Release")]
    [string]$Configuration = "Release",
    [ValidateSet("x64")]
    [string]$Platform = "x64",
    [string]$OutputDirectory = (Join-Path $PSScriptRoot "..\BundleArtifacts")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$Project = Join-Path $Root "src\PaperPulse.Windows\PaperPulse.Windows.csproj"
$ArtifactDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
$RootDirectory = [System.IO.Path]::GetFullPath($Root)

if (-not $ArtifactDirectory.StartsWith("$RootDirectory$([System.IO.Path]::DirectorySeparatorChar)", [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "OutputDirectory must be inside $RootDirectory."
}

if (Test-Path $ArtifactDirectory) {
    Remove-Item -Recurse -Force $ArtifactDirectory
}

New-Item -ItemType Directory -Force $ArtifactDirectory | Out-Null

$MSBuildPath = & (Join-Path $PSScriptRoot "Get-MSBuildPath.ps1")
$MSBuildArguments = @(
    $Project
    "/restore"
    "/t:Build"
    "/p:Configuration=$Configuration"
    "/p:Platform=$Platform"
    "/p:AppxPackageDir=$ArtifactDirectory\"
    "/p:GenerateAppxPackageOnBuild=true"
    "/p:AppxBundle=Never"
    "/p:UapAppxPackageBuildMode=SideloadOnly"
    "/p:AppxPackageSigningEnabled=false"
)

& $MSBuildPath @MSBuildArguments

if ($LASTEXITCODE -ne 0) {
    throw "Visual Studio MSBuild packaging failed with exit code $LASTEXITCODE."
}

$Packages = Get-ChildItem -Path $ArtifactDirectory -Recurse -File -Filter "*.msix"

if ($Packages.Count -eq 0) {
    throw "MSIX packaging completed without producing a .msix file in $ArtifactDirectory."
}

$Packages | ForEach-Object { Write-Host "MSIX artifact: $($_.FullName)" }
