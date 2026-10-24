[CmdletBinding()]
param(
    [string]$Godot = "C:\Users\karld\Desktop\Godot_v4.7.2-stable_win64_console.exe",
    [string]$Message = "",
    [switch]$OnlyCheck
)

# One click: validate, build the web version, publish to Cloudflare, commit and
# push to GitHub. Stops at the first failure. Editor noise (.import files,
# scenes/main.tscn, .wrangler) is never committed.

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot
$env:PATH = "C:\Program Files\nodejs;" + $env:PATH

function Step([string]$Text) { Write-Host "`n=== $Text ===" -ForegroundColor Green }
function Run([scriptblock]$Command) {
    & $Command
    if ($LASTEXITCODE -ne 0) { throw "Fehlgeschlagen (Code $LASTEXITCODE). Es wurde nichts weiter veroeffentlicht." }
}

Step "1/5 Pruefen"
Run { powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\check_project.ps1" -Godot $Godot }

if ($OnlyCheck) { Write-Host "Nur-Pruefen-Modus: fertig." -ForegroundColor Green; return }

Step "2/5 Web-Version bauen"
Run { powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\prepare_github_pages.ps1" -Godot $Godot }

Step "3/5 Zu Cloudflare hochladen"
Run { powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\publish_online.ps1" }

Step "4/5 Commit"
git add -- scripts server tests site tools docs README.md AGENTS.md THIRD_PARTY_ASSETS.md project.godot
git reset -q -- server/online/.wrangler 2>$null
if ([string]::IsNullOrWhiteSpace($Message)) {
    $Message = "Update " + (Get-Date -Format "yyyy-MM-dd HH:mm")
}
git diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "Keine neuen Aenderungen zum Committen."
} else {
    git commit -q -m $Message
    if ($LASTEXITCODE -ne 0) { throw "Commit fehlgeschlagen." }
}

Step "5/5 Zu GitHub pushen"
Run { git push origin main }

Write-Host "`nFertig. Seite am Handy neu laden (ggf. App einmal ganz schliessen)." -ForegroundColor Green
