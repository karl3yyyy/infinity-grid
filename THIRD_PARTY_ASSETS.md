# Third-party assets

All shipped third-party art is Creative Commons Zero (CC0 1.0). Attribution is
not required, but the original creators and source pages are recorded here for
auditability. Only the free tiers were downloaded; no EXTRA, SOURCE, paid, or
account-gated files are included.

| Asset | Creator | License | Official source | Original download | Downloaded (UTC) | Runtime paths | Processing |
| --- | --- | --- | --- | --- | --- | --- | --- |
| KayKit Character Pack: Adventurers 1.0 | Kay Lousberg | CC0 1.0 | https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0 | `kaykit-adventurers-main.zip` (SHA256 `e19176d799036452bc783c00dd1036e158c66c5a43b7285ccbfea3466d6f57bf`) | 2026-07-13 | `assets/characters/player/*.glb` | Knight, Rogue Hooded and Mage cleaned, normalized to 1.85 m, accessories filtered, seven required animations retained; Mage recolored white/light-blue/gold. |
| KayKit Character Pack: Skeletons 1.0 | Kay Lousberg | CC0 1.0 | https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0 | `kaykit-skeletons-main.zip` (SHA256 `bb666ec30ff243f54cffdd936fcceeb5c68cdb424d230fe637b7bfd756c0c8e6`) | 2026-07-13 | `assets/characters/enemy/*.glb` | Warrior, Rogue and Mage cleaned, normalized, dark-material variant applied, class weapons attached, seven required animations retained. |
| KayKit Fantasy Weapons Bits 1.0 FREE | Kay Lousberg | CC0 1.0 | https://kaylousberg.itch.io/fantasy-weapons-bits | `kaykit-fantasy-weapons-bits-free.zip` (SHA256 `1017144f85a994f405b731befa71ced360f5b60ed0b9c00c72e711c1633ce2d2`) | 2026-07-13 | Embedded in player/enemy archer GLBs | Free-tier longbows imported and attached to `handslot.r`; no paid variants used. |
| KayKit Dungeon Remastered 1.0 | Kay Lousberg | CC0 1.0 | https://github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0 | `kaykit-dungeon-remastered-main.zip` (SHA256 `8e92aa460f5be4252dff0cf030f92846ab74b875ce4756076ecce75b5d0c9bee`) | 2026-07-13 | `assets/environment/dungeon_*.glb` | Wall, pillar and crate re-exported as compact GLB; no collision or pathfinding state added. |
| Kenney Nature Kit 2.1 | Kenney | CC0 1.0 | https://kenney.nl/assets/nature-kit | `kenney_nature-kit.zip` (SHA256 `fa7974a0d342bfe63c38664ba9f8ec1a4aab8ea25f099bdc56870e33588c4d9d`) | 2026-07-13 | `assets/environment/nature_*.glb` | Oak, rock and bush selected and re-exported as compact GLB; scenery remains outside the logical grid. |
| Cloud Layers 2K HDRI | Greg Zaal / Poly Haven | CC0 1.0 | https://polyhaven.com/a/cloud_layers | `cloud_layers_2k.hdr` (SHA256 `66f8fbaf7452c332d05ce607e2c785a2f99578e2b3a095a11cfe9fde7e82c275`) | 2026-07-13 | `assets/sky/cloud_layers_2k.hdr` | Original 2K HDR copied without image modification and used by `PanoramaSkyMaterial`. |

KayKit's required Idle, Walking, melee, ranged, spellcast, hit and death clips
are included in both free character packs. No separate animation library or
retargeting source was needed.

