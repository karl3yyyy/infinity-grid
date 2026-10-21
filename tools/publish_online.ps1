[CmdletBinding()]
param(
    [switch]$SkipDeploy
)

# Publishes the web build in site/ together with the online relay to
# Cloudflare (server/online). Run tools/prepare_github_pages.ps1 first so
# site/ is current. Needs Node.js and a "npx wrangler login".

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$SiteRoot = Join-Path $ProjectRoot "site"
$OutRoot = Join-Path $ProjectRoot "build\online_site"
$PartSize = 20MB

if (-not (Test-Path -LiteralPath (Join-Path $SiteRoot "index.wasm"))) {
    throw "Web build not found in $SiteRoot. Run tools/prepare_github_pages.ps1 first."
}
if (Test-Path -LiteralPath $OutRoot) {
    Remove-Item -LiteralPath $OutRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $OutRoot | Out-Null
Get-ChildItem -LiteralPath $SiteRoot -Force |
    Where-Object { $_.Name -notin @("index.wasm", ".nojekyll", ".gdignore") } |
    Copy-Item -Destination $OutRoot -Recurse -Force

# Cloudflare static assets allow 25 MiB per file; worker.js joins the parts.
$Wasm = [System.IO.File]::ReadAllBytes((Join-Path $SiteRoot "index.wasm"))
$PartCount = [Math]::Ceiling($Wasm.Length / $PartSize)
if ($PartCount -ne 2) {
    throw "index.wasm needs $PartCount parts; update WASM_PARTS in server/online/worker.js."
}
for ($Index = 0; $Index -lt $PartCount; $Index++) {
    $Start = $Index * $PartSize
    $Length = [Math]::Min($PartSize, $Wasm.Length - $Start)
    $Part = New-Object byte[] $Length
    [Array]::Copy($Wasm, $Start, $Part, 0, $Length)
    [System.IO.File]::WriteAllBytes((Join-Path $OutRoot "index.wasm.part$Index"), $Part)
}
# Keep search engines away; only people with the link find the game.
Set-Content -LiteralPath (Join-Path $OutRoot "_headers") -Value "/*`n  X-Robots-Tag: noindex, nofollow" -Encoding ascii

if (-not $SkipDeploy) {
    Push-Location (Join-Path $ProjectRoot "server\online")
    try {
        npx --yes wrangler@4 deploy
        if ($LASTEXITCODE -ne 0) { throw "wrangler deploy failed." }
    }
    finally {
        Pop-Location
    }
}
