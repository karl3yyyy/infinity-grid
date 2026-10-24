[CmdletBinding()]
param(
    [string]$Godot = "D:\Sion File\downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BuildRoot = Join-Path $ProjectRoot "build"
$ExportLogs = Join-Path $ProjectRoot "logs\export"
$PackageDirectory = Join-Path $BuildRoot "packages"
New-Item -ItemType Directory -Force -Path $BuildRoot, $ExportLogs | Out-Null
$ResolvedBuildRoot = [System.IO.Path]::GetFullPath($BuildRoot).TrimEnd("\") + "\"
foreach ($name in @("windows", "web", "android", "packages")) {
    $directory = [System.IO.Path]::GetFullPath((Join-Path $BuildRoot $name))
    if (-not $directory.StartsWith($ResolvedBuildRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clean an output directory outside build/: $directory"
    }
    if (Test-Path -LiteralPath $directory) {
        Remove-Item -LiteralPath $directory -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}
New-Item -ItemType File -Force -Path (Join-Path $BuildRoot ".gdignore") | Out-Null

& (Join-Path $PSScriptRoot "check_project.ps1") -Godot $Godot

function Invoke-Export {
    param([string]$Preset, [string]$Mode, [string]$Output, [string]$LogName)
    $OutputPath = Join-Path $ProjectRoot $Output
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null
    $LogPath = Join-Path $ExportLogs $LogName
    & $Godot --headless --path $ProjectRoot $Mode $Preset $OutputPath 2>&1 | Tee-Object -FilePath $LogPath
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $OutputPath)) {
        throw "$Preset export failed. See $LogPath"
    }
}

Invoke-Export "Windows Desktop" "--export-release" "build\windows\InfinityGrid.exe" "windows.log"
Invoke-Export "Web Single-Threaded" "--export-release" "build\web\index.html" "web.log"
Invoke-Export "Android APK" "--export-debug" "build\android\InfinityGrid-debug.apk" "android.log"

$WindowsZip = Join-Path $PackageDirectory "InfinityGrid-Windows-x86_64.zip"
$WebZip = Join-Path $PackageDirectory "InfinityGrid-Web.zip"
if (Test-Path -LiteralPath $WindowsZip) { Remove-Item -LiteralPath $WindowsZip -Force }
if (Test-Path -LiteralPath $WebZip) { Remove-Item -LiteralPath $WebZip -Force }
Compress-Archive -Path (Join-Path $BuildRoot "windows\*") -DestinationPath $WindowsZip -CompressionLevel Optimal
Compress-Archive -Path (Join-Path $BuildRoot "web\*") -DestinationPath $WebZip -CompressionLevel Optimal

$Artifacts = @(
    "windows\InfinityGrid.exe",
    "web\index.html",
    "android\InfinityGrid-debug.apk",
    "packages\InfinityGrid-Windows-x86_64.zip",
    "packages\InfinityGrid-Web.zip"
)
$ArtifactRecords = foreach ($relative in $Artifacts) {
    $path = Join-Path $BuildRoot $relative
    [ordered]@{
        path = $relative -replace "\\", "/"
        size = (Get-Item -LiteralPath $path).Length
        sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant()
    }
}
$GitCommit = git -C $ProjectRoot rev-parse HEAD
$Manifest = [ordered]@{
    game = "Infinity Grid"
    version = "0.2.0"
    godot = (& $Godot --version).Trim()
    build_date = (Get-Date).ToUniversalTime().ToString("o")
    git_commit = $GitCommit
    tests = "Editor import, core integration suite, and main-scene smoke check passed"
    artifacts = $ArtifactRecords
}
$Manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $BuildRoot "build_manifest.json") -Encoding UTF8
$ChecksumLines = $ArtifactRecords | ForEach-Object { "$($_.sha256)  $($_.path)" }
$ChecksumLines | Set-Content -LiteralPath (Join-Path $BuildRoot "SHA256SUMS.txt") -Encoding ASCII

Write-Host "All release artifacts and packages were created." -ForegroundColor Green
