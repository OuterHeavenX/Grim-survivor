# Survivor character roster

Original Blender characters for all 13 playable classes: haunted survivors of
a dark-fantasy apocalypse. Seven are men and six are women, as before. Each
costume is built to read as its class from both the top-down sprite and the
selection portrait, using muted ash, leather, iron and bone palettes with
exactly one accent colour per class. There are no modern clothes, sneakers,
guns or military kit. Class IDs, abilities, unlocks and balance are unchanged.

| id | survivor | costume | accent |
|----|----------|---------|--------|
| rogue | Hooded Rogue | ash-brown peaked hood, capelet and long travelling cloak, leather jerkin, belt pouches | blood red lining |
| shadow | Shadowblade | close black wrapped hood, scarf over the lower face, dark wraps | cold steel-blue bindings, faintly lit eyes |
| pyro | Pyromancer | soot-black hooded robe, singed hem and mantle | smouldering ember-orange trim and cuffs |
| warden | Iron Warden | tarnished iron breastplate, layered pauldrons, gauntlets, greaves, wool mantle, grey beard | tarnished brass trim |
| flame | Flamecaller | burnt-red tabard over soot leathers, high scorched collar | flame-gold burning hands and collar |
| rime | Rimewarden | pale frosted fur hood and mantle, slate-blue leathers and robe | ice-cyan crystal shards and clasp |
| dancer | Bladedancer | grey fighting wraps, ragged short skirt, twin blades crossed on the back | faded jade sash and hilts |
| storm | Stormbound | storm-grey long coat and high collar, copper lightning rods | crackling blue-white bracers and eyes |
| reaper | The Reaper | deep black cowl over a gaunt face, ragged ankle-length robe, tattered mantle | ghost-green eyes |
| ravenmark | Ravenmark | layered black feather mantle and raven-feather crest, long open robe | bruised plum-violet lining and band |
| bonewright | Bonewright | stained leather apron, hide pauldrons, crown of tusks, rib-bone chest guard, belt skull | bone |
| plague | Plaguebearer | wide-brimmed hat, leather beaked mask, long waxed coat | bile-green lenses and vials |
| starcaller | Starcaller | tall pointed indigo-black hood and robe | pale-gold star motes and lit eyes |

Hoods, cloaks, mantles, robes, plate, feathers and bone pieces are modelled
geometry weighted to the same armature as the body (head, spine, hips, limb
bones), so the shared walk cycle drives the whole costume. Cloaks open at the
sides and robes flare wide enough that swinging arms and legs stay clear.
Renders use a strong warm key, a weak cool fill and two cold rim lights over a
dark ambient so silhouettes stand out against the dark ground. Faces have a
heavier brow ridge, sunken sockets and smaller eyes; hoods shade the eyes.

- `civilian_roster.blend`: editable meshes, materials, 13 named character
  collections and weighted armatures. Characters are spaced along X for editing.
- `civilian_roster.png`: full-roster review sheet.
- `roster_portraits.png`: all 13 selection portraits side by side.
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
characters for an art review, or `-- --preview --only rogue,reaper` to pick
classes. Preview runs do not overwrite the .blend or manifest. Run the full command before packing the roster.
Raw renders are reproducible intermediates and are ignored by Git.

The Blender action has a neutral pose at frame 0 and a 24-frame looping walk
at frames 1–25 (frame 25 repeats frame 1). The game uses six samples at frames
1, 5, 9, 13, 17 and 21, played at 11 fps. Each character retains its former
74–84 px sprite-cell height. The camera is orthographic, facing the front from
above; screen-down is the neutral direction, matching the existing 2D rotation
controller. All frames share one camera origin and scale, including idle. Packing
uses one padded bounding square across the entire cycle, so transparent margins
do not shrink the character and individual frames never shift or resize.

Skin, costume and accent colours (including emissive embers and eyes) are baked into the PNGs and use white modulation;
the existing red damage flash still applies. Selection portraits are rendered
from the same character models. `tools/build_sprites.gd` now rebuilds enemies
only, so it cannot restore the soldier placeholders over the survivor art.

Run `godot --path . --script res://test/capture_civilians.gd` without headless
mode to regenerate selection and gameplay screenshots. The character test
covers all 13 sprites, distinct animation frames, movement/idle transitions,
facing, portraits and damage flashes without writing save data.

These models are original geometry created by the included Blender script.
There are no downloaded meshes, textures, AI image inputs or third-party model
dependencies. The original CraftPix packs remain untouched.
