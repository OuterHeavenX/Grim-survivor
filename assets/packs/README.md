# Asset packs

Third-party art packs, unpacked from the archives that were previously eight
loose `.zip` files in the repository root.

| Directory | From | Files | Size |
| --- | --- | --- | --- |
| `ui/` | `UI.zip` | 209 | 14 MB |
| `tileset/` | `tileset.zip` | 375 | 27 MB |
| `tileset-pack-2/` | `tileset pack 2.zip` | 338 | 18 MB |
| `tileset-pack-3/` | `tileset pack 3.zip` | 271 | 12 MB |
| `top-down-soldiers/` | `top down soldies.zip` | 1224 | 60 MB |
| `top-down-zombies/` | `top down zombies.zip` | 570 | 35 MB |
| `topdown-tanks-cars/` | `topdown assets tanks cars.zip` | 108 | 51 MB |
| `topdown-bosses/` | `topdown bosses.zip` | 917 | 181 MB |

Directory names are the archive names normalised to lower-case and hyphens
(`top down soldies` → `top-down-soldiers`, correcting the typo).

## What was unpacked, and what was not

Only what a Godot project can actually use: `.png` sprites and tilesets,
`.scml` Spriter animation data, and every `License.txt` and `readme.txt`.
The archives' 17 `.ini` files were all Windows `desktop.ini` cruft, so they
were dropped.

A `.gitattributes` here keeps the vendored files byte-exact — no line-ending
conversion, no diffing — and marks them vendored so they stay out of GitHub's
language statistics.

The editable source art was deliberately left in the archives — `.ai`, `.eps`
and `.psd` are 2.3 GB of the 2.7 GB total (51 Illustrator files alone are
2 GB), and Godot cannot import any of them. The original archives are kept
under `_source-art/`, still tracked in Git LFS, so nothing is lost.

## Why this directory carries a `.gdignore`

`export_presets.cfg` uses `export_filter="all_resources"`, so every resource
Godot imports is written into `index.pck`. Left visible to the engine, these
3,962 PNGs would be imported on every editor open and shipped in the web
build, taking `index.pck` from 823 KB to roughly 400 MB and making the
deployed game unusable.

`.gdignore` makes Godot skip this directory and everything under it. Verified:
with it in place the exported pack is byte-for-byte the same size as before
(823,064 bytes, 118 entries, none from here).

**To actually use a sprite, copy it out of here into `assets/` proper** — that
part of the tree is visible to the engine, so only the art you deliberately
move across gets imported and shipped.

## Licensing

All eight packs are from [CraftPix](https://craftpix.net); each directory keeps
its own `License.txt` pointing at https://craftpix.net/file-licenses/. Check
those terms before redistributing the art or shipping it in a release — they
place limits on redistribution that apply to this repository as well as to
builds made from it.
