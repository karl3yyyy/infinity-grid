# Third-party assets

All shipped third-party art is Creative Commons Zero (CC0 1.0); the VT323 font is SIL OFL 1.1. Attribution is
not required, but the original creators and source pages are recorded here for
auditability. Only the free tiers were downloaded; no EXTRA, SOURCE, paid, or
account-gated files are included.

| Asset | Creator | License | Official source | Original download | Downloaded (UTC) | Runtime paths | Processing |
| --- | --- | --- | --- | --- | --- | --- | --- |
| VT323 | Peter Hull, The VT323 Project Authors | SIL Open Font License 1.1 | https://fonts.google.com/specimen/VT323 | `google/fonts` repository, `ofl/vt323/VT323-Regular.ttf` | 2026-10-23 | `assets/fonts/VT323-Regular.ttf` | Unmodified; license in `assets/licenses/VT323-OFL.txt`. Used for the terminal-style main menu. |
| Universal Base Characters [Standard] | Quaternius | CC0 1.0 (License_Standard.txt in the zip) | https://quaternius.itch.io/universal-base-characters | `Universal Base Characters[Standard].zip` (SHA256 `fdbf1804c90dfc1e…`, free tier via itch.io) | 2026-10-24 | `assets/characters/humans/*.gltf/.bin`, base-colour textures | Godot glTF files and hairstyles only; base-colour textures downscaled to 256 px, normal/roughness maps replaced by 4 px flat stand-ins; skeleton retargeted to Godot's humanoid profile (`bone_map_humans.tres`). Outfits, cyber gear and the pixel look are added at runtime. |
| Universal Animation Library [Standard] | Quaternius | CC0 1.0 (License.txt in the zip) | https://opengameart.org/content/universal-animation-library | `universal_animation_librarystandard.zip` (SHA256 `18ff1a7215f4852b…`) | 2026-10-24 | `assets/characters/humans/animation_library.glb` | Godot GLB unchanged; retargeted to Godot's humanoid profile on import (`bone_map_animations.tres`). |


