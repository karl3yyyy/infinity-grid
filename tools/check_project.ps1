[CmdletBinding()]
param(
    [string]$Godot = "D:\Sion File\downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$LogDirectory = Join-Path $ProjectRoot "logs\validation"
New-Item -ItemType Directory -Force -Path $LogDirectory | Out-Null

if (-not (Test-Path -LiteralPath $Godot)) {
    throw "Godot executable not found: $Godot"
}

function Invoke-GodotCheck {
    param(
        [string]$Name,
        [string[]]$Arguments
    )

    $LogPath = Join-Path $LogDirectory "$Name.log"
    Write-Host "`n=== $Name ===" -ForegroundColor Cyan
    Write-Host "$Godot $($Arguments -join ' ')"
    $PreviousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & $Godot @Arguments 2>&1 | Tee-Object -FilePath $LogPath
    $ExitCode = $LASTEXITCODE
    $ErrorActionPreference = $PreviousErrorActionPreference
    if ($ExitCode -ne 0) {
        throw "$Name failed with exit code $ExitCode. See $LogPath"
    }
    $FatalPatterns = "SCRIPT ERROR|Parse Error|Parser Error|Failed loading resource|Node not found|ERROR:"
    $FatalMatches = Select-String -Path $LogPath -Pattern $FatalPatterns -CaseSensitive:$false | Where-Object { $_.Line -notmatch "Tripo Bridge" }
    if ($FatalMatches) {
        $FatalMatches | ForEach-Object { Write-Host $_.Line -ForegroundColor Red }
        throw "$Name emitted fatal diagnostics. See $LogPath"
    }
}

Invoke-GodotCheck -Name "editor-load" -Arguments @(
    "--headless", "--path", $ProjectRoot, "--editor", "--quit"
)
Invoke-GodotCheck -Name "ui-feature-tests" -Arguments @(
    "--headless", "--path", $ProjectRoot, "--script", "res://tests/ui_features_test.gd"
)
Invoke-GodotCheck -Name "core-tests" -Arguments @(
    "--headless", "--path", $ProjectRoot, "--script", "res://tests/test_runner.gd"
)
Invoke-GodotCheck -Name "chaos-tests" -Arguments @(
    "--headless", "--path", $ProjectRoot, "--script", "res://tests/chaos_test.gd"
)
Invoke-GodotCheck -Name "ffa-tests" -Arguments @(
    "--headless", "--path", $ProjectRoot, "--script", "res://tests/ffa_test.gd"
)
Invoke-GodotCheck -Name "lan-tests" -Arguments @(
    "--headless", "--path", $ProjectRoot, "--script", "res://tests/lan_test.gd"
)
Invoke-GodotCheck -Name "main-smoke" -Arguments @(
    "--headless", "--path", $ProjectRoot, "--quit-after", "120"
)

Write-Host "`nAll Infinity Grid validation checks passed." -ForegroundColor Green
