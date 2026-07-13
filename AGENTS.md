# Tactical Slash Project Instructions

## Project goal

Build a playable 3D turn-based tactical grid game in Godot 4 using GDScript.

The first playable prototype must contain:

- A 10x10 square grid with pathfinding obstacles.
- Three player-controlled swordsmen.
- Three AI enemy swordsmen.
- Mouse-based unit and tile selection.
- Movement range highlighting.
- Grid-based pathfinding.
- Player and enemy turns.
- A melee slash attack.
- Damage, hit reaction and death.
- Win and lose conditions.
- Placeholder models where final assets do not exist.

## Technical requirements

- Use Godot 4 and typed GDScript.
- Do not use C#.
- Do not add external plugins without approval.
- Keep game rules separate from visuals.
- Store authoritative unit positions as Vector2i grid coordinates.
- Do not calculate grid state only from Node3D global positions.
- Use signals to reduce hard dependencies between systems.
- Avoid very large scripts.
- Prefer one clear responsibility per script.
- Use descriptive English filenames and identifiers.
- Add comments only where the reason is not obvious.
- Do not modify files outside this repository.

## Architecture

Separate the project into these systems:

1. GridManager
2. GridCell data
3. Unit
4. UnitMovement
5. TurnManager
6. BattleManager
7. PlayerController
8. EnemyController
9. AttackAction
10. BattleUI

Supporting focused systems include CameraController, EnemyController,
AttackAction, DamageNumber and HitEffect. Keep each responsibility separate.

## Combat requirements

The slash attack sequence must be:

1. Validate that the target is an adjacent enemy.
2. Rotate the attacker toward the target.
3. Play the slash animation.
4. Apply damage only at the animation hit event.
5. Play hit reaction, sound and placeholder hit effect.
6. Play death animation when HP reaches zero.
7. End the acting unit's action only after the animation finishes.

Do not apply damage immediately when the attack button is pressed.

## Development workflow

Before modifying files:

1. Inspect the current repository.
2. Explain the proposed files and architecture.
3. Check the Git working tree.

After modifying files:

1. Run the Godot headless project validation script.
2. Fix all parser, resource and missing-node errors.
3. Report every created and modified file.
4. Explain how to test the feature manually.
5. Do not claim success unless validation passed.

## Scope control

Complete only the requested milestone.

Do not add:

- Multiplayer
- Inventory
- Equipment
- Dialogue systems
- Procedural worlds
- Online services
- Save systems
- Complex shaders

unless explicitly requested.
