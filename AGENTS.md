# Infinity Grid Project Instructions

## Project goal

Build Infinity Grid, a playable 3D turn-based card strategy game in Godot 4 using GDScript.

The first playable prototype must contain:

- One 5x5 board with horizontal wraparound; top and bottom edges stay closed.
- A pool of movement cards; five are drawn per match, two per side plus one shared pass card.
- A Master and four Students per side.
- Card-based legal-move highlighting and capture.
- Capturing the opposing Master wins the match.
- A local bot opponent for Bot Training.
- Render-only side projections that map back to the same logical cells and units.
- An oblique player-side camera, portrait layout and responsive main menu.
- Bot difficulty levels (easy, medium, hard).

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

1. GridManager and GridCell data
2. BattleUnit and UnitMovement
3. MovementCard
4. OnitamaBattleManager, including the local bot
5. PlayerController
6. CameraController
7. OnitamaUI and MainMenu

Keep game rules separate from rendering and keep edge projections non-authoritative.

## Move and capture requirements

Every move must:

1. Match one of the selected card's relative offsets.
2. Wrap horizontal coordinates with modulo; reject moves past the top or bottom.
3. Capture an opposing unit on the destination; capturing its Master ends the match.
4. Animate the one authoritative unit while syncing its visual edge projections.
5. Exchange the used card with the shared pass card before changing turns.

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

Do not implement internet networking, shop transactions, ranked services, or
online profiles without an explicit backend milestone. Their menu entries are
status pages only; the local profile name/avatar is stored on-device.

Approved exceptions: Wi-Fi play and online room codes. `tools/lan_host.gd`
runs on a PC in the same network, serves the web export and relays moves
between two browsers; `server/online/worker.js` (Cloudflare Worker) relays
moves for rooms joined by code. Both speak one protocol (`scripts/network/`)
and stay relays; every client runs the rules itself.

Approved backend milestone: player accounts and a cosmetics shop paid with
in-game credits. `server/online/accounts.js` (one Durable Object per account,
opened with an account code, no passwords or e-mail) alone decides credits and
ownership; `scripts/network/account_service.gd` only displays and caches them.
Players start as guests and may sign in with e-mail + password or Google
(`server/online/auth.js`, PBKDF2 password hashes); a login only leads to an
account. Apple sign-in is approved but waits for an Apple developer account.

Approved: credit packs bought with real money through Stripe Checkout
(`server/online/payments.js`). Credits are only granted from a verified Stripe
webhook, never from the client. Secret keys live in Cloudflare secrets and are
never committed; the owner sets them up and switches from test to live mode.
