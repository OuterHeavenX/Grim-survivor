# Spectral companions

Original Blender art for the three summonable companions. They are spectral
allies, so each has a dark body, one cold emissive accent and a faint Fresnel
rim in that accent. The rim makes them read as ghostly while staying visible
on dark ground. Camera, lights, colour management, the 24-frame loop and the
sheet layout match the survivor roster (`art/civilians`).

| id | companion | look | accent | cell |
|----|-----------|------|--------|------|
| hound | Grave Hound | Gaunt quadruped. Charcoal hide over showing ribs, a bony spine ridge, ragged ears and hackles, an open fanged jaw. Trots on a diagonal-pair cycle. | spectral green `#7dffb0`: eyes and spine embers | 84 px |
| archer | Bone Archer | Skeleton in a tattered hood, ragged mantle and cloak, rag loincloth and shin wraps. Carries a longbow and a quiver. Survivor biped rig and walk. | pale blue `#8fd8ff`: eye sockets, bowstring, nocks, fletching and a heart in the ribcage | 80 px |
| knight | Wraith Knight | Tall, faceless and in blackened plate: great helm with horns, spiked pauldrons and a torn cloak. Carries a greatsword low in the right hand. Uses a heavy walk with a shorter stride and more bob and sway. | violet `#c08cff`: helm slit, breath slit, blade runes and pommel gem | 104 px (about 1.3x a survivor) |

- `../../assets/sprites/companion_<id>_walk.png`: six square cells in one row
  (frames 1, 5, 9, 13, 17, 21 of the 24-frame loop). They face screen-down, like
  the survivor sheets.
- `../../assets/sprites/companion_<id>_portrait.png`: 384x384 portraits, framed
  like the survivor portraits.
- `companions_sheet.png`: review sheet with each portrait, an enlarged walk strip
  and the walk strip at in-game size.

## Rebuild

From the project root, with Blender 5.2 and Python/Pillow installed:

```sh
blender --background --factory-startup --python tools/build_companions.py
python tools/pack_companions.py
godot --headless --path . --import
```

To render only some companions, add `-- --only hound,knight` to the Blender
command. Add `-- --preview` to render just the portrait and walk frame 5, or
`-- --samples 12` for quicker test renders. Raw renders go to `renders/`, are
reproducible, and Git ignores them.

The Blender action has a neutral pose at frame 0 and a looping walk at
frames 1–25. Packing uses one padded bounding square across the whole cycle,
so frames never shift or resize. Each walk sheet is therefore scaled to fill
its cell, and the cell size sets the companion's on-screen size.

All geometry is original and built procedurally by `tools/build_companions.py`.
The helpers are copied from `tools/build_civilians.py`, which is unchanged.
There are no downloaded meshes, textures or AI image inputs.
