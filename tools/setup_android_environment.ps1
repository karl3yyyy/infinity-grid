[CmdletBinding()]
param(
    [string]$Godot = "D:\Sion File\downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe",
    [string]$AndroidSdk = "$env:LOCALAPPDATA\Android\Sdk",
    [string]$JavaSdk = ""
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
if (-not $JavaSdk) {
    $JavaSdk = Get-ChildItem -LiteralPath "$env:LOCALAPPDATA\Programs\Temurin" -Directory -Filter "jdk-17*" -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $JavaSdk -or -not (Test-Path -LiteralPath (Join-Path $JavaSdk "bin\java.exe"))) {
    throw "OpenJDK 17 was not found."
}
$required = @(
    (Join-Path $AndroidSdk "platform-tools\adb.exe"),
    (Join-Path $AndroidSdk "cmdline-tools\latest\bin\sdkmanager.bat"),
    (Join-Path $AndroidSdk "platforms\android-35\android.jar"),
    (Join-Path $AndroidSdk "build-tools\35.0.0\apksigner.bat")
)
foreach ($path in $required) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required Android component is missing: $path"
    }
}

$KeystoreDirectory = Join-Path $env:APPDATA "Godot\keystores"
$Keystore = Join-Path $KeystoreDirectory "debug.keystore"
New-Item -ItemType Directory -Force -Path $KeystoreDirectory | Out-Null
if (-not (Test-Path -LiteralPath $Keystore)) {
    & (Join-Path $JavaSdk "bin\keytool.exe") -genkeypair -v `
        -keystore $Keystore -storepass android -alias androiddebugkey -keypass android `
        -keyalg RSA -keysize 2048 -validity 10000 `
        -dname "CN=Android Debug,O=Android,C=US"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create the standard local Android debug keystore."
    }
}

$EditorSettings = Join-Path $env:APPDATA "Godot\editor_settings-4.7.tres"
if (-not (Test-Path -LiteralPath $EditorSettings)) {
    throw "Godot 4.7 editor settings were not found: $EditorSettings"
}
$SettingsText = Get-Content -LiteralPath $EditorSettings -Raw
$NormalizedSdk = $AndroidSdk -replace "\\", "/"
$NormalizedJava = $JavaSdk -replace "\\", "/"
if ($SettingsText -notmatch [regex]::Escape($NormalizedSdk) -or $SettingsText -notmatch [regex]::Escape($NormalizedJava)) {
    throw "Godot Editor Android SDK/Java SDK paths are not configured to the verified locations."
}

Write-Host "Android export environment is ready." -ForegroundColor Green
Write-Host "SDK: $AndroidSdk"
Write-Host "JDK: $JavaSdk"
Write-Host "Debug keystore: $Keystore"
