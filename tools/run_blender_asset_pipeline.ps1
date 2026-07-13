[CmdletBinding()]
param(
    [string]$Blender = "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$LogDirectory = Join-Path $ProjectRoot "logs\blender"
$LogPath = Join-Path $LogDirectory "asset-pipeline.log"
New-Item -ItemType Directory -Force -Path $LogDirectory | Out-Null

if (-not (Test-Path -LiteralPath $Blender)) {
    $Blender = Get-ChildItem -Path "C:\Program Files\Blender Foundation" -Filter blender.exe -Recurse -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $Blender -or -not (Test-Path -LiteralPath $Blender)) {
    throw "Blender executable was not found."
}

$Arguments = @(
    "--background",
    "--factory-startup",
    "--python", (Join-Path $PSScriptRoot "prepare_3d_assets.py"),
    "--",
    "--project-root", $ProjectRoot
)

$ErrorActionPreference = "Continue"
& $Blender @Arguments 2>&1 | Tee-Object -FilePath $LogPath
$BlenderExitCode = $LASTEXITCODE
$ErrorActionPreference = "Stop"
if ($BlenderExitCode -ne 0) {
    throw "Blender asset pipeline failed with exit code $BlenderExitCode. See $LogPath"
}
if (-not (Select-String -LiteralPath $LogPath -SimpleMatch "PIPELINE_OK" -Quiet)) {
    throw "Blender exited without the PIPELINE_OK marker. See $LogPath"
}

Write-Host "Blender assets prepared successfully." -ForegroundColor Green
