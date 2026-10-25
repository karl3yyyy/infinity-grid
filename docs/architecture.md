# Architecture

## Startup

`scripts/core/main.gd` builds the scene in code: the cyberpunk arena
(`CyberEnvironment`), the board (`GridManager`), the camera, the HUD with the
main menu (`GridBattleUI`, `MainMenu`), input (`PlayerController`), piece
animation (`UnitMovement`) and the match (`GridBattleManager`). On the web it
also keeps the installed app up to date.

## Rules and state

- `GridBattleManager` owns the match: dealing cards, turns, legal moves,
  captures, the card exchange, passing, threefold repetition and the result.
  It also drives the bot (`BotAI`, which searches a compact copy of the state)
  and network matches (`NetworkMatch`).
- `MovementCard` holds a card's relative offsets; destinations wrap
  horizontally with modulo and are rejected past the top or bottom row.
- `BattleUnit.grid_position` (a `Vector2i`) and `GridCell.occupant` are the
  authoritative state. 3D positions are only ever derived from them.

## Board and pieces

- `GridManager` builds the single 5×5 board and render-only copies of the
  outer columns on both sides, so the wraparound is visible. Clicks on a copy
  map back to the real cell. `BoardSkinPainter` paints each player's half.
- A `BattleUnit` is a plinth, a team glow and a `FighterSprite`. The fighter is
  a rigged human (`FighterModel`, dressed from `CharacterRoster` and
  `CharacterSkins`, with skinned coats and hair from `ClothBuilder`) rendered
  into a small viewport and drawn on a camera-facing quad with a pixel shader.
  Its edge copies show the same frames through mirror quads.
- `UnitMovement` plays a move in the character's fighting style;
  `CombatEffects` provides the spell circles, lightning, shots and debris.

## Chaos lab

Spielen > CHAOS is a lab of combinable variants (hidden king, shifting tiles,
card effects). `scripts/chaos/`: `ChaosRules` (options, king cells, tiles,
shields), `CardEffect` (strike/push/shield/swap by card category) and
`ChaosBot` are node-free. `GridBattleManager.chaos` is set only in chaos
matches. Add a variant by adding a flag to `ChaosRules`, an entry in
`PlayPages.CHAOS_VARIANTS` and its hooks in the manager. Local vs bot only.

## Finite Grid (four players)

`scripts/ffa/`: runs in the 3D game with the normal figures, cards, camera and
fighting styles, on a closed 9x9 board with a plain slab for a floor (no arena
platforms yet). `FfaRules` (pure) holds pieces, hands, turn order, eliminations
and tiles; `FfaBot` plays the bots; `FfaFloor` is a `GridManager` without
wraparound; `FfaBattle` shows the match and takes the input. The camera turns to
the seat of the human to move (`CameraController.set_seat_view`), so every
player's "forward" points up the screen. The two cards of every other player lie
flat on the floor behind that player's side, turned like on a real table
(`FfaWorldHands`), so their diagrams point the way the figures move; the played
card passes clockwise (`FfaRules.pass_giver`). Chaos options: wandering tiles
(`ChaosRules`) and card effects (`FfaEffects`; a turn is step OR effect, the
EFFEKT button of the HUD). Opened from Spielen > FINITE GRID, next to CHAOS.

**Online rooms.** Up to four humans share a room (five-digit code, or a friend's
invitation, which carries the code). `GroupClient` talks to `GroupRoom` in
`server/online/group_room.js`, a relay like the two-player room: it seats the
players, deals the same nine cards and one random seed to everybody, numbers the
turns and drops repeats or turns for a foreign seat. Every client plays the whole
rules; the host's client plays the bots and sends their turns. A player who
leaves is replaced by a bot (`seat_left`) and the next player becomes host.
Lobby pages: `GroupRoomPages`. Not done yet: resuming after a dropped
connection, and the hidden king of the chaos lab.

## Interface

- `MainMenu` is the terminal-style menu. Pages for the shop (`ShopPages`),
  logins (`LoginPages`), profile pictures (`AvatarPicker`) and the swipeable
  character gallery (`CharacterShowcase`) draw into it.
- `GridBattleUI` is the in-match HUD with cards (`CardView`), pause menu and rules.

## Networking

All clients run the rules themselves; servers only relay and check turn order.

- `MatchClient` speaks one WebSocket protocol to either the Wi-Fi host
  (`tools/lan_host.gd` with `LanHostServer`) or the Cloudflare Worker.
- `server/online/worker.js`: one Durable Object per room (turn history,
  reconnects) and a lobby for quick matches.
- `server/online/group_room.js`: rooms for up to four players (Finite Grid),
  see "Finite Grid" above.
- `server/online/accounts.js`: accounts, credits and owned cosmetics. Only the
  server changes them; `AccountService` displays and caches them.
- `server/online/auth.js`: e-mail/password (PBKDF2) and Google sign-in.
  A login leads to an account; guests become accounts by registering.
- `server/online/payments.js`: Stripe Checkout for credit packs. Credits are
  granted only from a verified webhook. The checkout and Google sign-in open in
  their own window (`ExternalWindow`) so the game keeps its browser storage.

## Tests

`tests/test_runner.gd` covers rules and the match flow, `tests/lan_test.gd` the
Wi-Fi protocol and server/game agreement (cards, shop prices),
`tests/online_test.gd` the Worker, `tests/group_online_test.gd` and
`tests/group_battle_test.gd` the four-player rooms (both need a local
`wrangler dev`, see the test headers). `tools/check_project.ps1` runs the tests
that need no server.

## Screen layout

On the Finite Grid pages BILDSCHIRM chooses how the phone is held (`ScreenLayout`):
landscape only turns the screen for Finite Grid matches, the HUD stays the same.
