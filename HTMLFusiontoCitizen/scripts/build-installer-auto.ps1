$ErrorActionPreference = "Stop"

$p1 = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
$p2 = "C:\Program Files\Inno Setup 6\ISCC.exe"

if (Test-Path $p1) {
    $env:ISCC_PATH = $p1
}
elseif (Test-Path $p2) {
    $env:ISCC_PATH = $p2
}

& (Join-Path $PSScriptRoot "build-installer.ps1")
