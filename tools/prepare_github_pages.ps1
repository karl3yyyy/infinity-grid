[CmdletBinding()]
param(
    [string]$Godot = "D:\Sion File\downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Ensure-Directory {
    param([Parameter(Mandatory)][string]$Path)

    for ($Attempt = 1; $Attempt -le 5; $Attempt++) {
        try {
            [System.IO.Directory]::CreateDirectory($Path) | Out-Null
            if (Test-Path -LiteralPath $Path -PathType Container) {
                return
            }
        }
        catch {
            if ($Attempt -eq 5) {
                throw
            }
        }
        Start-Sleep -Milliseconds 500
    }
    throw "Unable to create directory after five attempts: $Path"
}

function Clear-DirectoryContents {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$AllowedRoot
    )

    Ensure-Directory -Path $Path
    $ResolvedAllowedRoot = [System.IO.Path]::GetFullPath($AllowedRoot).TrimEnd("\") + "\"
    $ResolvedPath = [System.IO.Path]::GetFullPath($Path).TrimEnd("\") + "\"
    if (-not $ResolvedPath.StartsWith($ResolvedAllowedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clean a directory outside its allowed root: $ResolvedPath"
    }
    foreach ($Item in Get-ChildItem -LiteralPath $Path -Force) {
        for ($Attempt = 1; $Attempt -le 5; $Attempt++) {
            try {
                Remove-Item -LiteralPath $Item.FullName -Recurse -Force
                break
            }
            catch {
                if ($Attempt -eq 5) {
                    throw
                }
                Start-Sleep -Milliseconds 500
            }
        }
    }
}

try {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
    $BuildRoot = Join-Path $ProjectRoot "build"
    $WebRoot = Join-Path $BuildRoot "web"
    $SiteRoot = Join-Path $ProjectRoot "site"
    $ExportLogDirectory = Join-Path $ProjectRoot "logs\export"
    $ExportLog = Join-Path $ExportLogDirectory "github-pages-web.log"

    if (-not (Test-Path -LiteralPath $Godot -PathType Leaf)) {
        throw "Godot executable not found: $Godot"
    }

    $GodotCommand = $Godot
    & $GodotCommand --version *> $null
    if ($LASTEXITCODE -ne 0) {
        $GodotSourceDirectory = Split-Path -Parent $Godot
        $GodotMainName = (Split-Path -Leaf $Godot) -replace '_console\.exe$', '.exe'
        $GodotMainSource = Join-Path $GodotSourceDirectory $GodotMainName
        if (-not (Test-Path -LiteralPath $GodotMainSource -PathType Leaf)) {
            throw "Godot failed to start and its companion executable was not found: $GodotMainSource"
        }
        $GodotCache = Join-Path $env:LOCALAPPDATA "TacticalSlash\Godot-4.7"
        New-Item -ItemType Directory -Force -Path $GodotCache | Out-Null
        Copy-Item -LiteralPath $Godot, $GodotMainSource -Destination $GodotCache -Force
        $GodotCommand = Join-Path $GodotCache (Split-Path -Leaf $Godot)
        & $GodotCommand --version *> $null
        if ($LASTEXITCODE -ne 0) {
            throw "Godot failed to start from both the requested path and local cache."
        }
        Write-Warning "Godot could not run from $Godot; using the local cache at $GodotCommand."
    }

    $PresetText = Get-Content -LiteralPath (Join-Path $ProjectRoot "export_presets.cfg") -Raw
    if ($PresetText -notmatch 'name="Web Single-Threaded"' -or
        $PresetText -notmatch 'variant/thread_support=false' -or
        $PresetText -notmatch 'variant/extensions_support=false') {
        throw "The Web Single-Threaded export preset is missing or has threads/extensions enabled."
    }

    Ensure-Directory -Path $BuildRoot
    Ensure-Directory -Path $ExportLogDirectory
    $ResolvedBuildRoot = [System.IO.Path]::GetFullPath($BuildRoot).TrimEnd("\") + "\"
    $ResolvedWebRoot = [System.IO.Path]::GetFullPath($WebRoot)
    if (-not $ResolvedWebRoot.StartsWith($ResolvedBuildRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clean a Web output directory outside build/: $ResolvedWebRoot"
    }
    Clear-DirectoryContents -Path $WebRoot -AllowedRoot $BuildRoot

    $WebEntry = Join-Path $WebRoot "index.html"
    & $GodotCommand --headless --path $ProjectRoot --export-release "Web Single-Threaded" $WebEntry 2>&1 |
        Tee-Object -FilePath $ExportLog
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $WebEntry -PathType Leaf)) {
        throw "Godot Web export failed. See $ExportLog"
    }

    $ResolvedProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot).TrimEnd("\") + "\"
    $ResolvedSiteRoot = [System.IO.Path]::GetFullPath($SiteRoot)
    if (-not $ResolvedSiteRoot.StartsWith($ResolvedProjectRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to clean a Pages directory outside the project: $ResolvedSiteRoot"
    }
    Clear-DirectoryContents -Path $SiteRoot -AllowedRoot $ProjectRoot
    Get-ChildItem -LiteralPath $WebRoot -Force | Copy-Item -Destination $SiteRoot -Recurse -Force
    New-Item -ItemType File -Force -Path (Join-Path $SiteRoot ".nojekyll") | Out-Null
    New-Item -ItemType File -Force -Path (Join-Path $SiteRoot ".gdignore") | Out-Null

    $RequiredFiles = @(
        ".gdignore",
        ".nojekyll",
        "index.html",
        "index.js",
        "index.wasm",
        "index.pck",
        "index.png",
        "index.icon.png",
        "index.apple-touch-icon.png",
        "index.audio.worklet.js",
        "index.audio.position.worklet.js"
    )
    foreach ($RelativePath in $RequiredFiles) {
        $RequiredPath = Join-Path $SiteRoot $RelativePath
        if (-not (Test-Path -LiteralPath $RequiredPath -PathType Leaf)) {
            throw "Required Pages file is missing: site/$RelativePath"
        }
    }

    $TextAssets = Get-ChildItem -LiteralPath $SiteRoot -File -Recurse |
        Where-Object { $_.Extension -in @(".html", ".js", ".json", ".css") }
    $UnsafeReferences = $TextAssets | Select-String -Pattern 'file://|localhost|(?<![A-Za-z0-9_])[A-Za-z]:[\\/]' -CaseSensitive:$false
    if ($UnsafeReferences) {
        $UnsafeReferences | ForEach-Object { Write-Host $_.Line -ForegroundColor Red }
        throw "The Web export contains a local or absolute resource reference."
    }

    $OversizedFiles = Get-ChildItem -LiteralPath $SiteRoot -File -Recurse |
        Where-Object { $_.Length -gt 100MB }
    if ($OversizedFiles) {
        $OversizedFiles | Format-Table FullName, Length -AutoSize
        throw "A Pages file exceeds 100 MB."
    }

    $Records = Get-ChildItem -LiteralPath $SiteRoot -File -Recurse |
        Sort-Object FullName |
        ForEach-Object {
            [PSCustomObject]@{
                Path = $_.FullName.Substring($ResolvedSiteRoot.Length).TrimStart("\") -replace "\\", "/"
                Size = $_.Length
                SHA256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()
            }
        }
    $Records | Format-Table -AutoSize
    Write-Host "GitHub Pages files are ready in $SiteRoot" -ForegroundColor Green
}
catch {
    Write-Error $_
    exit 1
}
