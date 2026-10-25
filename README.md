# Infinity Grid

A turn-based card strategy game on an endless board, built with Godot 4.
Two players each command a **KERN** and four **ECHOS** (the side pieces) on a 5×5
grid whose left and right edges wrap around. Movement cards decide where a
piece may go; capture the opposing KERN to win.

The game is set inside a Matrix-like simulation: a blue retro circuit board,
pixel-art fighters with cyber gear, and a green terminal interface.
The interface language is German.

**Play in the browser:** https://infinity-grid.infinitygrid.workers.dev
(mirror: https://karl3yyyy.github.io/infinity-grid/)

## Features

- **Rules:** 5×5 board with horizontal wraparound (top and bottom are closed),
  19 movement cards with five drawn per match, card exchange through a shared
  pass card, a pass when no move is possible, and a draw on threefold repetition.
- **Opponents:** a local bot (easy, medium, hard), two players on one device,
  Wi-Fi play hosted by a PC, online play by room code (up to four friends in a Finite Grid room, also by invitation), and a quick online match
  against a random opponent with automatic reconnect.
- **Characters:** 12 collectible characters with four fighting styles
  (mage, brawler, gunner, sorcerer), each with its own capture animation and two
  extra skins. The ECHOS are copies of your character the Grid made.
- **Board skins:** circuit board, code rain, lava, synthwave, gold and starfield
  patterns for your half of the board.
- **Accounts:** play as a guest, then sign in with e-mail and password or
  Google and choose a permanent username; credits, purchases and the profile
  picture follow the account.
- **Ranked and friends:** Elo-rated ranked games refereed by the server
  (tiers Bit-Runner to Root Sovereign, leaderboard), friends by username with
  online status, challenges and invitations.
- **Shop:** credits are earned through daily bonuses and bot wins and spent on
  characters, skins, echoes and board skins; credit packs can be bought with
  Stripe (currently in test mode).
- **Phone-first:** portrait layout, touch controls, installable web app that
  updates itself.

## How to play

1. Pick one of your two movement cards.
2. Pick one of your pieces. Highlighted squares show where the card allows it to go.
3. Move there. Landing on an opposing piece captures it.
4. The card you played swaps with the pass card; your opponent gets the old pass card next.
5. Capture the opposing KERN, or move any of your pieces onto its starting square, to win.

Cards show a 5×5 diagram: the dark square is the piece, coloured squares are
its targets. Moves past the left or right edge come back on the other side.

**Controls:** click or tap cards, pieces and squares; right-click or long press
cancels; Escape opens the pause menu. On desktop, WASD/arrow keys pan, Q/E
rotate and the mouse wheel zooms the camera.

## Run it locally

1. Install [Godot 4.7](https://godotengine.org/download) (standard build, not .NET).
2. Open `project.godot` and press **F5**.

Validate the project (editor load, rule tests, network tests, smoke test):

```powershell
powershell -ExecutionPolicy Bypass -File tools/check_project.ps1 -Godot "<path to Godot console exe>"
```

Logs go to `logs/validation/`.

## Project layout

| Path | Contents |
| --- | --- |
| `scripts/battle/` | Match flow and rules (`grid_battle_manager.gd`), movement cards, bot AI, capture effects, network matches |
| `scripts/grid/` | The cylindrical board, its cells and the procedurally painted board skins |
| `scripts/units/` | Pieces (`BattleUnit`) and their move/attack animations |
| `scripts/characters/` | Character roster, skins, profile pictures and the pixel-art fighter renderer |
| `scripts/ui/` | Terminal main menu, in-match HUD, cards, character gallery, shop and login pages |
| `scripts/network/` | Online, Wi-Fi and account clients |
| `scripts/camera/`, `scripts/controllers/`, `scripts/core/` | Camera, input, cyberpunk arena and startup |
| `server/online/` | Cloudflare Worker: rooms, quick-match lobby, accounts, logins, payments |
| `tests/` | Headless tests for rules, Wi-Fi play and the online server |
| `tools/` | Validation, web export, publishing and the Wi-Fi host |
| `site/` | The exported web build served by GitHub Pages |
| `docs/` | Architecture notes and the (German) project overview |

See [docs/architecture.md](docs/architecture.md) for how the pieces fit together.

## Online server

The server is a Cloudflare Worker on the free plan (`server/online/`).
Durable Objects hold one game room each, the quick-match lobby, player accounts
and logins. Every client runs the game rules itself; the server relays moves
and checks turn order. Credits and owned items are decided by the server only.

Run it locally for the online tests:

```bash
cd server/online
npx wrangler dev --port 8787
```

Then, from the project root, with `INFINITY_GRID_ONLINE=ws://127.0.0.1:8787`:

```bash
godot --headless --path . --script res://tests/online_test.gd
```

Secrets are stored with `npx wrangler secret put <NAME>` and never committed:
`STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` and `GOOGLE_CLIENT_SECRET`.
Public settings (Stripe price ids, Google client id) are in `wrangler.toml`.

## Wi-Fi play without internet

1. On a PC, run `WLAN-Spiel starten.bat`. It exports the web build when needed
   and prints addresses such as `http://192.168.178.37:8060`.
2. Open that address on two phones in the same network.
3. Choose **Multiplayer → Im WLAN spielen** on both.

The PC (`tools/lan_host.gd`) serves the page and relays moves.

## Publishing

```powershell
powershell -File tools/prepare_github_pages.ps1 -Godot "<path to Godot console exe>"
powershell -File tools/publish_online.ps1
git add site; git commit -m "Rebuild the web version"; git push
```

The first command exports the web build to `site/` (GitHub Pages deploys it
on push). The second deploys the build and the server to Cloudflare; it needs
Node.js and `npx wrangler login`.

Desktop and Android builds: `tools/build_release.ps1`
(Android needs `tools/setup_android_environment.ps1` first).

## Tech

- Godot 4.7, typed GDScript, Compatibility renderer; web export single-threaded.
- Characters: Quaternius Universal Base Characters and Universal Animation
  Library (CC0), dressed at runtime and rendered into low-resolution viewports
  with a pixel shader.
- Board patterns, profile symbols, outfits and effects are generated in code.

## Licenses

Project code is under the [MIT License](LICENSE). Third-party assets keep
their own licenses (CC0 characters, SIL OFL font); see
[THIRD_PARTY_ASSETS.md](THIRD_PARTY_ASSETS.md).
