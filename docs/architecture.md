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
`tests/online_test.gd` the Worker. `tools/check_project.ps1` runs them all.
