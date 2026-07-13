# Tactical Slash

Tactical Slash is a playable 3D turn-based grid tactics prototype built with
Godot 4.7 and typed GDScript. It uses only Godot primitive meshes, so the full
battle works without external models, plugins, textures, or paid assets.
The current milestone has passed headless validation and a complete UI-driven battle playtest.

## Play

1. Open `project.godot` with Godot 4.7 stable.
2. Press **F6** from `scenes/main.tscn`, or **F5** from anywhere in the editor.
3. Left-click a blue swordsman, then a blue highlighted tile to move.
4. Choose **ATTACK** and click an adjacent red enemy, or click an adjacent red
   enemy directly. Damage is applied at the sword-impact event, not on click.
5. Choose **WAIT** to finish that unit, or **END TURN** to hand control to AI.
6. Right-click or use **CANCEL** to leave target/selection mode before moving.

Camera controls: WASD or arrow keys pan, Q/E rotate, and the mouse wheel zooms.
Eliminate all three raiders to win; losing all three swordsmen causes defeat.

## Features

- 10×10 3D grid with hover, selection, movement, attack, occupied, and blocked
  cell states.
- BFS movement reachability and shortest paths around five obstacles and units.
- Three player swordsmen and three AI raiders with authoritative `Vector2i`
  coordinates.
- Smooth tile-by-tile movement and a rotatable/zoomable tactical camera.
- Procedural body, limbs, sword, shield, selection ring, shadows, and team color.
- Idle breathing, alternating walk, articulated wind-up/slash, hit recoil/flash,
  and persistent death pose.
- Single timed slash hit event, damage formula, hit stop, sparks, camera shake,
  and floating damage numbers.
- Player/enemy phases, per-unit move/attack limits, AI turns, victory, defeat,
  restart, and quit UI.
- Empty `AudioStreamPlayer3D` placeholders; adding no audio never breaks play.

## Architecture

- `scripts/grid`: logical cells, visual cell states, occupancy, BFS, paths.
- `scripts/units`: unit rules/model/animation and step movement.
- `scripts/battle`: battle state machine, orchestration, and timed attacks.
- `scripts/controllers`: mouse-to-grid input and sequential enemy AI.
- `scripts/camera`: smooth tactical orbit/pan/zoom/shake camera.
- `scripts/ui`: responsive HUD, actions, selection stats, battle result.
- `scripts/effects`: procedural hit sparks and damage numbers.
- `tests`: headless scene and core rule assertions.

Game rules are stored independently from primitive-mesh visuals. Grid occupancy
and movement use `Vector2i`; world positions are only the rendered projection.

## Validation

From PowerShell:

```powershell
Set-Location D:\GameProjects
.\tools\check_project.ps1
```

The script runs editor/resource loading, core automated assertions, and a
120-frame Main-scene smoke test. Full output is written under `logs/`.

Equivalent direct commands:

```powershell
& "D:\Sion File\downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless --path D:\GameProjects --editor --quit
& "D:\Sion File\downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless --path D:\GameProjects --script res://tests/test_runner.gd
& "D:\Sion File\downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless --path D:\GameProjects --quit-after 120
```

## Windows export

`export_presets.cfg` targets `build/windows/TacticalSlash.exe`. This machine did
not initially contain Godot 4.7 export templates, so install the official 4.7
templates through **Editor > Manage Export Templates**, then run:

```powershell
& "D:\Sion File\downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless --path D:\GameProjects --export-release "Windows Desktop"
```

The editor-playable project does not require export templates.

## Replacing the procedural fighters

Import a GLB with a rig and `AnimationPlayer`, then replace `_build_model()` in
`scripts/units/unit.gd` with an instantiated character scene. Preserve the
`BattleUnit` root API, selection ring, status label, and grid coordinate. Map
Idle/Walk/Hit/Death to the imported animation names. For Slash, add a Call Method
Track at blade contact that invokes the same one-shot damage event currently
located in `AttackAction.execute`; keep action completion after the animation's
finished signal. This swaps visuals without changing combat, grid, turns, or AI.
