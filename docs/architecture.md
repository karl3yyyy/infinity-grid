# Architecture notes

`Main` builds the environment and wires focused systems. `BattleManager` owns the
battle flow but delegates coordinates and paths to `GridManager`, motion to
`UnitMovement`, the animation hit event to `AttackAction`, mouse projection to
`PlayerController`, and opponent decisions to `EnemyController`. Signals report
state, health, death, attack, and controller events without scene-path guesses.

Authoritative state flows from `BattleUnit.grid_position` and each
`GridCell.occupant`; `Node3D.position` is updated only after a validated path.

