# Architecture notes

`Main` builds the meadow environment and wires the game systems.
`OnitamaBattleManager` owns card dealing, turn flow, capture rules, and the local
bot. `GridManager` owns the single 5x5 cylindrical board; `MovementCard` defines
relative legal destinations; `UnitMovement` animates one authoritative unit;
`PlayerController` maps screen input to logical cells; and `CameraController`
frames the board from the player's side.

`BattleUnit.grid_position` and `GridCell.occupant` are authoritative. Side-strip
tiles and repeated figure visuals are render-only projections; clicks on them
map to the same central coordinates. The bot evaluates legal card moves and
prefers Master captures and moves toward the opposing Master. `MainMenu` stores a
local display name/avatar and exposes collection data; online menu destinations
remain placeholders until an online backend exists.
