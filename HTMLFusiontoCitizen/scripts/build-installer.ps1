param(
    [string]$SourceDir = (Join-Path $PSScriptRoot ".."),
    [string]$OutputDir = (Join-Path $PSScriptRoot "..\dist")
)

$ErrorActionPreference = "Stop"

$resolvedSourceDir = (Resolve-Path $SourceDir).Path
if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}
$resolvedOutputDir = (Resolve-Path $OutputDir).Path

$manifestPath = Join-Path $resolvedSourceDir "manifest.json"
$version = "1.0.0"
if (Test-Path $manifestPath) {
    $manifest = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json
    if ($manifest.version) {
        $version = $manifest.version
    }
}

$issPath = Join-Path $PSScriptRoot "HTMLFusiontoCitizenInstaller.iss"
if (!(Test-Path $issPath)) {
    throw "Installer script not found: $issPath"
}

$candidateIsccPaths = @(
    $env:ISCC_PATH,
    (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"),
    (Join-Path $env:ProgramFiles "Inno Setup 6\ISCC.exe")
) | Where-Object { $_ -and (Test-Path $_) }

$isccPath = $candidateIsccPaths | Select-Object -First 1
if (-not $isccPath) {
    throw "Inno Setup compiler (ISCC.exe) not found. Install Inno Setup 6 or set ISCC_PATH env var."
}

& $isccPath "/DSourceDir=$resolvedSourceDir" "/DOutputDir=$resolvedOutputDir" "/DAppVersion=$version" $issPath
if ($LASTEXITCODE -ne 0) {
    throw "ISCC failed with exit code $LASTEXITCODE"
}

Write-Host "Installer build completed in: $resolvedOutputDir"
