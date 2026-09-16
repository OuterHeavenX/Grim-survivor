# Civilian character roster

Original Blender characters replace all 13 soldier-based playable sprites.
Seven men wear casual shirts/sweaters, trousers and sneakers. Six women wear
blouses/cardigans/sweaters, knee-length skirts and sneakers. Hairstyles, skin
tones and clothing colours vary across the roster. No military equipment is
modelled. Class IDs, abilities, unlocks and balance are unchanged.

- `civilian_roster.blend`: editable meshes, materials, 13 named character
  collections and weighted armatures. Characters are spaced along X for editing.
- `civilian_roster.png`: full-roster review sheet.
- `manifest.json`: class/body/outfit mapping and render provenance.
- `*_in_game.png`: captures from the actual Godot renderer.
- `../../assets/sprites/player_*`: shipped walk sheets, idle poses and portraits.

## Rebuild

From the project root, with Blender 5.2 and Python/Pillow installed:

```sh
blender --background --factory-startup --python tools/build_civilians.py
python tools/pack_civilians.py
godot --headless --path . --editor --import
godot --headless --path . --script res://test/test_civilians.gd
godot --headless --path . --export-release Web
```

Use `-- --preview` after the Blender command to render only the first two
characters for an art review. Run the full command before packing the roster.
Raw renders are reproducible intermediates and are ignored by Git.

The Blender action has a neutral pose at frame 0 and a 24-frame looping walk
at frames 1–25 (frame 25 repeats frame 1). The game uses six samples at frames
1, 5, 9, 13, 17 and 21, played at 11 fps. Each character retains its former
74–84 px sprite-cell height. The camera is orthographic, facing the front from
above; screen-down is the neutral direction, matching the existing 2D rotation
controller. All frames share one camera origin and scale, including idle. Packing
uses one padded bounding square across the entire cycle, so transparent margins
do not shrink the character and individual frames never shift or resize.

Skin and clothing colours are baked into the PNGs and use white modulation;
the existing red damage flash still applies. Selection portraits are rendered
from the same character models. `tools/build_sprites.gd` now rebuilds enemies
only, so it cannot restore the soldier placeholders over the civilian art.

Run `godot --path . --script res://test/capture_civilians.gd` without headless
mode to regenerate selection and gameplay screenshots. The character test
covers all 13 sprites, distinct animation frames, movement/idle transitions,
facing, portraits and damage flashes without writing save data.

These models are original geometry created by the included Blender script.
There are no downloaded meshes, textures, AI image inputs or third-party model
dependencies. The original CraftPix packs remain untouched.
