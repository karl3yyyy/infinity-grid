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
    Where-Object { $_.Name -notin @("index.wasm", "index.pck", ".nojekyll", ".gdignore") } |
    Copy-Item -Destination $OutRoot -Recurse -Force

# Cloudflare static assets allow 25 MiB per file; worker.js joins the parts.
# The expected part counts must match SPLIT_FILES in server/online/worker.js.
# The pck is smaller than 20 MB now, so it is cut into 10 MB pieces to keep two parts.
foreach ($Split in @(@{ Name = "index.wasm"; Parts = 2; Size = $PartSize }, @{ Name = "index.pck"; Parts = 2; Size = 10MB })) {
    $Bytes = [System.IO.File]::ReadAllBytes((Join-Path $SiteRoot $Split.Name))
    $PartSize = $Split.Size
    $PartCount = [Math]::Ceiling($Bytes.Length / $PartSize)
    if ($PartCount -ne $Split.Parts) {
        throw "$($Split.Name) needs $PartCount parts; update SPLIT_FILES in server/online/worker.js and this script."
    }
    for ($Index = 0; $Index -lt $PartCount; $Index++) {
        $Start = $Index * $PartSize
        $Length = [Math]::Min($PartSize, $Bytes.Length - $Start)
        $Part = New-Object byte[] $Length
        [Array]::Copy($Bytes, $Start, $Part, 0, $Length)
        [System.IO.File]::WriteAllBytes((Join-Path $OutRoot "$($Split.Name).part$Index"), $Part)
    }
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
