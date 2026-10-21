[CmdletBinding()]
param(
    [string]$Godot = "",
    [int]$Port = 8060,
    [switch]$Rebuild
)

# Starts the Wi-Fi host: exports the web build if needed, then serves it to
# phones in the same network and relays their moves.

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$WebRoot = Join-Path $ProjectRoot "build\web"

if (-not $Godot) {
    $Candidates = @(
        (Get-ChildItem -Path ([Environment]::GetFolderPath("Desktop")) -Filter "Godot_v4*_console.exe" -ErrorAction SilentlyContinue),
        (Get-ChildItem -Path (Join-Path $env:USERPROFILE "Downloads") -Filter "Godot_v4*_console.exe" -Recurse -Depth 2 -ErrorAction SilentlyContinue)
    ) | Where-Object { $_ } | Sort-Object LastWriteTime -Descending
    if (-not $Candidates) {
        throw "Godot wurde nicht gefunden. Starte das Skript mit -Godot <Pfad zur Godot_..._console.exe>."
    }
    $Godot = @($Candidates)[0].FullName
}

$Pck = Join-Path $WebRoot "index.pck"
$Stale = $false
if (Test-Path -LiteralPath $Pck) {
    $BuiltAt = (Get-Item -LiteralPath $Pck).LastWriteTime
    $Stale = [bool](Get-ChildItem -Path (Join-Path $ProjectRoot "scripts"), (Join-Path $ProjectRoot "scenes"), (Join-Path $ProjectRoot "assets") -Recurse -File |
        Where-Object { $_.LastWriteTime -gt $BuiltAt } | Select-Object -First 1)
}
if ($Rebuild -or $Stale -or -not (Test-Path -LiteralPath $Pck)) {
    Write-Host "Exportiere die Web-Version ..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $WebRoot | Out-Null
    & $Godot --headless --path $ProjectRoot --export-release "Web Single-Threaded" (Join-Path $WebRoot "index.html")
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath (Join-Path $WebRoot "index.pck"))) {
        throw "Web-Export fehlgeschlagen. Sind die Godot-Exportvorlagen installiert (Editor > Exportvorlagen verwalten)?"
    }
}

& $Godot --headless --path $ProjectRoot --script "res://tools/lan_host.gd" -- "--web=$WebRoot" "--port=$Port"
