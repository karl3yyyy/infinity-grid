# GitHub Pages Online Test

- Test date: 2026-07-14 (Asia/Hong_Kong)
- Pages URL: https://sion-rgb.github.io/tactical-slash/
- Browser: Codex in-app browser (Chromium, 1280x720 viewport)
- Workflow run: https://github.com/sion-rgb/tactical-slash/actions/runs/29276482564

## HTTP results

| Resource | Status | Content-Type | Content-Length |
| --- | ---: | --- | ---: |
| `/tactical-slash/` | 200 | `text/html; charset=utf-8` | 5,446 |
| `index.html` | 200 | `text/html; charset=utf-8` | 5,446 |
| `index.js` | 200 | `application/javascript; charset=utf-8` | 279,815 |
| `index.wasm` | 200 | `application/wasm` | 39,509,339 |
| `index.pck` | 200 | `application/octet-stream` | 10,727,796 |
| `index.png` | 200 | `image/png` | 21,443 |
| `index.icon.png` | 200 | `image/png` | 16,588 |
| `index.apple-touch-icon.png` | 200 | `image/png` | 15,489 |
| `index.audio.worklet.js` | 200 | `application/javascript; charset=utf-8` | 7,298 |
| `index.audio.position.worklet.js` | 200 | `application/javascript; charset=utf-8` | 2,973 |

HTTPS is enforced. Direct entry and refresh both returned the game, and all
resource references used the repository subpath without `localhost`, `file://`,
or a local Windows path. No tested resource returned 404. The WASM response used
the required `application/wasm` MIME type.

## Browser and gameplay results

- The Godot loading overlay completed and was removed; the 1280x720 canvas,
  10x10 board, sky, materials, scenery, and all six characters rendered.
- Selected the player Swordsman, moved it along highlighted cells, and used
  WAIT to complete its first action.
- Ended the first player turn. The enemy AI moved and attacked, reduced the
  player Archer from 10/10 to 6/10 HP, and returned control at Round 02.
- Moved the Swordsman adjacent to the Dark Priest and completed Slash; the
  target HP decreased and the Swordsman action completed.
- Selected the Archer, entered attack targeting, fired at the highlighted Bone
  Archer with clear line of sight, and observed the target HP decrease.
- Selected the Priest, entered Heal targeting, and restored the player Archer
  from 6/10 to 10/10 HP.
- Reloaded the direct Pages URL; the loading sequence completed and a fresh
  Round 01 board rendered again.
- Browser console: no error or warning entries during load, both player rounds,
  the enemy AI turn, class actions, or reload. No audio-related error appeared.

## Known limitations

- The in-app browser reserved or ignored F11, so browser fullscreen could not be
  independently verified in this automated session; the game remained stable
  after the keypress.
- Audible output was not assessed by a human listener, although no audio error
  was logged.
- The browser test covered two player phases and one enemy phase, not a complete
  victory or defeat match.
- The Android APK has static/export verification but has not yet been tested on
  a physical Android device for touch behavior.
