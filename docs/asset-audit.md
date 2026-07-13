# Asset audit

## Acceptance policy

Only CC0, Public Domain, or CC BY 4.0 assets with an identifiable creator and
official source are accepted. Every adopted pack was downloaded from its
creator's site or official GitHub organization, its included license was read,
and its archive SHA256 was recorded in `THIRD_PARTY_ASSETS.md`.

## Adopted sources

- KayKit Adventurers, Skeletons and Dungeon Remastered: official
  `KayKit-Game-Assets` GitHub organization; included `LICENSE.txt` files state
  CC0 and name Kay Lousberg.
- KayKit Fantasy Weapons Bits: official Kay Lousberg itch.io page, free upload
  only; its included `License.txt` states CC0.
- Kenney Nature Kit: official Kenney download; included `License.txt` states
  CC0 and identifies Nature Kit 2.1.
- Poly Haven Cloud Layers: official Poly Haven 2K HDR endpoint and asset page;
  the page identifies Greg Zaal and CC0.

## Rejected or unnecessary alternatives

- KayKit EXTRA and SOURCE tiers were not downloaded because they are paid.
- Quaternius Universal Animation Library was not needed because all seven
  required animations exist in the adopted KayKit free character GLBs.
- Unofficial model mirrors and convenience conversions were rejected because
  the official sources supplied usable GLTF/GLB files.
- No BlenderKit, Sketchfab, marketplace, AI-generated, or unknown-license asset
  was used.

Original extracted packages remain under `assets/source_assets/` and are hidden
from Godot by `.gdignore`. Blender outputs and the processing manifest live in
`assets/characters/`, `assets/environment/`, `assets/sky/`, and
`assets/processed_asset_manifest.json`.

