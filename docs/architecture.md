# Architecture notes

`Main` builds the licensed environment and wires focused systems.
`BattleManager` owns battle flow but delegates coordinates, line of sight, and
paths to `GridManager`; motion to `UnitMovement`; melee, projectile, and healing
timing to action classes; pointer and gesture projection to `PlayerController`;
and bounded class-specific decisions to `EnemyController`. Signals report state,
health, death, actions, and controller events without scene-path guesses.

Authoritative state flows from `BattleUnit.grid_position` and each
`GridCell.occupant`; `Node3D.position` is updated only after a validated path.
`UnitClassData` is the single source for combat stats and ranges. `BattleUnit`
maps semantic animation states to the clips inside each processed GLB, keeping
model structure independent from combat and AI rules.
