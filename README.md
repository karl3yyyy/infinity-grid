# Tactical Slash

Tactical Slash is a local two-player 3D strategy game built with Godot 4. Each
player commands a Master and four Students on a 5x5 board whose left and right
edges wrap around. Five movement cards are dealt between both players and a
shared pass space; after each move, the used card trades places with the pass
card. Capture the opposing Master to win.

[**Play Online**](https://sion-rgb.github.io/tactical-slash/) ·
[**Download for Windows**](https://github.com/sion-rgb/tactical-slash/releases/download/v0.2.0/TacticalSlash-Windows-x86_64.zip) ·
[**Download Android APK**](https://github.com/sion-rgb/tactical-slash/releases/download/v0.2.0/TacticalSlash-debug.apk) ·
[**View Third-Party Asset Licenses**](THIRD_PARTY_ASSETS.md)

## Play

Open `project.godot` in Godot 4.7 stable and press F6 from
`scenes/main.tscn`, or run the exported build. The game is hot-seat multiplayer:
both players take turns on the same device.

1. Choose one of your two movement cards.
2. Select one of your five figures; highlighted fields show legal moves.
3. Move onto an opponent's figure to capture it. Capturing the opposing Master
  wins the game.
4. The played card moves to the shared pass space; take the card that was there.
5. Players alternate after every move. Gold lines mark the connected board edges.

Desktop/Web controls:

- **Left Click:** select cards, figures, and destination tiles.
- **Right Click:** cancel.
- **WASD / Arrow Keys:** pan the camera.
- **Q / E:** rotate the camera.
- **Mouse Wheel:** zoom.
- **Escape:** pause or close the current menu.
- **F11:** toggle fullscreen.

Android controls:

- **Tap:** select and confirm.
- **Drag:** pan the camera.
- **Pinch:** zoom.
- **UI Buttons:** select a movement card.
- Two-finger rotate orbits the camera and long press cancels. The UI respects
  the platform safe area; Android Back closes the current mode/menu before
  exiting.

## Movement Cards

The five shuffled cards are **Crane**, **Wave**, **Comet**, **Shell**, and
**Vortex**. Each card defines three relative moves. Horizontal moves wrap around
the board; moves past the top or bottom edge are invalid. Player 2's forward
direction is mirrored. The HUD shows both hands and the shared pass card.

## Versions, Web, and licensing

- Godot 4.7 stable with typed GDScript and the Compatibility renderer.
- Blender 5.1.2 for the reproducible 3D asset preparation pipeline.
- The workspace MCP server uses Node.js 24 and `@coding-solo/godot-mcp`.
- The browser build uses the **Web Single-Threaded** preset without threads,
  SharedArrayBuffer, extensions, or GDExtension.
- Character and environment assets are CC0 packs from KayKit and Kenney; the
  HDR sky is a CC0 Poly Haven asset. See [THIRD_PARTY_ASSETS.md](THIRD_PARTY_ASSETS.md)
  and [the asset audit](docs/asset-audit.md) for authors, sources, and licenses.
- Original project code is available under the [MIT License](LICENSE). The MIT
  License does not replace the separate licenses for third-party assets.
- Release hashes: [SHA256SUMS.txt](https://github.com/sion-rgb/tactical-slash/releases/download/v0.2.0/SHA256SUMS.txt).

## Architecture

- `scripts/grid`: logical cells, occupancy, cylindrical neighbors, and paths.
- `scripts/units`: unit state, GLB loading, animation mapping, and movement.
- `scripts/battle`: movement cards, card exchange, turn flow, and capture rules.
- `scripts/controllers`: desktop/touch input.
- `scripts/camera`: smooth tactical pan, orbit, zoom, gesture input, and shake.
- `scripts/ui`: responsive safe-area HUD, actions, menu, and results.
- `scripts/effects`: hit, projectile, healing, and floating-number effects.
- `tools`: Blender asset preparation, validation, Android setup, release build,
  and local Web serving.
- `tests`: headless integration and rule assertions.

`BattleUnit.grid_position` and `GridCell.occupant` are authoritative. Rendered
`Node3D` positions never replace the `Vector2i` game state. Licensed visuals are
loaded behind the unit API, so game rules do not depend on model node names.

## Validate

From PowerShell:

```powershell
Set-Location D:\GameProjects
powershell -ExecutionPolicy Bypass -File .\tools\check_project.ps1
```

This performs editor/resource loading, 34 core assertions, and a Main-scene
smoke test. Logs are written to `logs/validation/`; Blender and export logs use
`logs/blender/` and `logs/export/`.

## Rebuild 3D assets

The processed runtime assets are committed. To reproduce them from the audited
source archives with Blender 5.1:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_blender_asset_pipeline.ps1
```

Original archives/extractions live under `assets/source_assets/` and are
excluded from Git and Godot import. Runtime GLBs and the HDR are under
`assets/characters/`, `assets/environment/`, and `assets/sky/`. See
`THIRD_PARTY_ASSETS.md`, `docs/asset-audit.md`, and `assets/licenses/`.

## Build releases

Export templates must match Godot 4.7. Android additionally uses OpenJDK 17 and
Android SDK Platform/Build Tools 35 or newer. Verify the local Android setup:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\setup_android_environment.ps1
```

Create all artifacts and checksums:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\build_release.ps1
```

Outputs:

- `build/windows/TacticalSlash.exe`
- `build/web/index.html`
- `build/android/TacticalSlash-debug.apk`
- `build/packages/TacticalSlash-Windows-x86_64.zip`
- `build/packages/TacticalSlash-Web.zip`
- `build/build_manifest.json`
- `build/SHA256SUMS.txt`

Serve the Web build over HTTP (not `file://`):

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\serve_web.ps1
```

Prepare the tracked GitHub Pages directory from a fresh Single-Threaded export:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\prepare_github_pages.ps1
```

The Android package is `com.sionbarzahd.tacticalslash`, version `0.2.0`
(version code 2), arm64, landscape. The generated debug keystore, SDK, JDK,
build outputs, and logs are intentionally excluded from Git.
