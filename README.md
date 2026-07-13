# Tactical Slash

Tactical Slash is a 3D turn-based tactical RPG built with Godot 4. Players
command a Swordsman, Archer and Priest against an enemy squad with matching
classes. The battle takes place on a 10x10 grid and uses animated 3D characters,
class-specific actions, line of sight, healing, and class-aware enemy AI.

[**Play Online**](https://sion-rgb.github.io/tactical-slash/) ·
[**Download for Windows**](https://github.com/sion-rgb/tactical-slash/releases/download/v0.2.0/TacticalSlash-Windows-x86_64.zip) ·
[**Download Android APK**](https://github.com/sion-rgb/tactical-slash/releases/download/v0.2.0/TacticalSlash-debug.apk) ·
[**View Third-Party Asset Licenses**](THIRD_PARTY_ASSETS.md)

## Play

Open `project.godot` in Godot 4.7 stable and press F6 from
`scenes/main.tscn`, or run the exported build.

1. Select a blue unit and click/tap a highlighted tile to move.
2. Use **ATTACK** for a class attack, **HEAL** for a Priest ally, **WAIT** to
   finish the selected unit, or **END TURN** to hand control to the AI.
3. Swordsmen attack adjacent targets. Archers fire at range 2-5 with line of
   sight. Priests cast Holy Bolt at range 2-4 and heal allies at range 1-4.
4. Eliminate all three skeletons to win; losing all three heroes causes defeat.

Desktop/Web controls:

- **Left Click:** select, move, and choose a target.
- **Right Click:** cancel.
- **WASD / Arrow Keys:** pan the camera.
- **Q / E:** rotate the camera.
- **Mouse Wheel:** zoom.
- **Escape:** pause or close the current menu.
- **F11:** toggle fullscreen; **M:** toggle mute.

Android controls:

- **Tap:** select and confirm.
- **Drag:** pan the camera.
- **Pinch:** zoom.
- **UI Buttons:** rotate, cancel, and end the turn.
- Two-finger rotate orbits the camera and long press cancels. The UI respects
  the platform safe area; Android Back closes the current mode/menu before
  exiting.

## Classes

| Class | HP | ATK | DEF | MOVE | Actions |
| --- | ---: | ---: | ---: | ---: | --- |
| Swordsman | 14 | 6 | 2 | 4 | Slash, range 1 |
| Archer | 10 | 5 | 1 | 4 | Bow shot, range 2-5, line of sight |
| Priest | 9 | 3 | 1 | 3 | Holy Bolt, range 2-4; Heal 6 HP, range 1-4 |

- **Swordsman:** melee defense and Slash.
- **Archer:** range 2-5 with line of sight.
- **Priest:** Heal and Holy Bolt.

Damage from arrows and spells is applied at projectile impact. Healing is
clamped to maximum HP and cannot target enemies or defeated units. Enemy AI
uses class-specific positioning and priorities; its Priest heals the lowest HP
ratio ally below 50%, otherwise it attacks with Dark Bolt.

## Versions, Web, and licensing

- Godot 4.7 stable with typed GDScript and the Compatibility renderer.
- Blender 5.1.2 for the reproducible 3D asset preparation pipeline.
- The browser build uses the **Web Single-Threaded** preset without threads,
  SharedArrayBuffer, extensions, or GDExtension.
- Character and environment assets are CC0 packs from KayKit and Kenney; the
  HDR sky is a CC0 Poly Haven asset. See [THIRD_PARTY_ASSETS.md](THIRD_PARTY_ASSETS.md)
  and [the asset audit](docs/asset-audit.md) for authors, sources, and licenses.
- Original project code is available under the [MIT License](LICENSE). The MIT
  License does not replace the separate licenses for third-party assets.
- Release hashes: [SHA256SUMS.txt](https://github.com/sion-rgb/tactical-slash/releases/download/v0.2.0/SHA256SUMS.txt).

## Architecture

- `scripts/grid`: logical cells, occupancy, line of sight, BFS, and paths.
- `scripts/units`: class data, unit state, GLB loading, animation mapping, and
  tile-by-tile movement.
- `scripts/battle`: turn flow plus melee, projectile, and healing actions.
- `scripts/controllers`: desktop/touch input and bounded class-aware enemy AI.
- `scripts/camera`: smooth tactical pan, orbit, zoom, gesture input, and shake.
- `scripts/ui`: responsive safe-area HUD, actions, menu, and results.
- `scripts/effects`: hit, projectile, healing, and floating-number effects.
- `tools`: Blender asset preparation, validation, Android setup, release build,
  and local Web serving.
- `tests`: headless integration and rule assertions.

`BattleUnit.grid_position` and `GridCell.occupant` are authoritative. Rendered
`Node3D` positions never replace the `Vector2i` game state. Licensed visuals are
loaded behind the unit API, so battle rules do not depend on model node names.

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
