# Grim Survivors

A grimdark vampire-survivors-lite built in Godot 4.7. Survive five minutes,
slay the Herald. Weapons fire on their own; you move, dodge and pick up gems.

Four playable classes — Hooded Rogue, Shadowblade, Pyromancer, Iron Warden —
and six meta upgrades bought with soul shards banked across runs. Targets both
desktop and mobile web (portrait, 720×1280, on-screen joystick when a
touchscreen is present).

## Repository layout

```
project.godot          Godot project settings
export_presets.cfg     Web export preset (output: build/web/)
icon.svg               Project icon
upgrades_preview.png   Meta-upgrade screen art

scenes/main.tscn       Main scene — a single Node2D running src/main.gd
src/                   Game code (25 scripts)
test/                  Standalone test scenes (8 scripts)
assets/audio/          Sound effects and music (21 WAVs)

build/web/             Exported web build — committed so the game can be served
                       straight from the repo. Regenerate it, don't hand-edit.
tools/recover/         How the source was recovered from the build; see below
```

Everything else the editor creates (`.godot/`) is ignored and rebuilt on first
open.

### `src/`

Four scripts are autoloaded singletons (see `[autoload]` in `project.godot`):

| Script | Role |
| --- | --- |
| `game_manager.gd` | Run state, classes, weapons, meta upgrades, save data |
| `audio_man.gd` | Sound effect and music playback |
| `juice_man.gd` | Screen shake, hit particles, damage numbers |
| `lighting.gd` | 2D light auras attached to entities |

The rest are instanced by the game: `main.gd` drives the run, `player.gd`,
`enemy.gd`, `projectile.gd` and `weapons.gd` carry the combat, `gem.gd`,
`shard.gd` and `chest.gd` the pickups, `ground.gd`, `bg.gd`, `fog.gd` the
Ashen Hollow backdrop, and `hud.gd`, `char_select.gd`, `title_screen.gd`,
`levelup_ui.gd`, `loot_ui.gd`, `upgrades_ui.gd`, `pause_menu.gd`,
`end_screen.gd`, `joystick_ui.gd`, `ui_bits.gd` the interface.

## Running it

Open the project folder in **Godot 4.7.2** and press play. Nothing else to
install.

The scripts in `test/` are standalone harnesses for individual systems — set one
as the main scene, or run it directly, to exercise that system on its own.

## Building the web export

```sh
godot --headless --path . --export-release "Web"
```

Writes to `build/web/`. That directory carries a `.gdignore` so Godot does not
import its own output back into the project — without it, the export sweeps
copies of its own icons into the pack.

Serving the build needs the two cross-origin isolation headers
(`Cross-Origin-Opener-Policy: same-origin`,
`Cross-Origin-Embedder-Policy: require-corp`); opening `index.html` off the
filesystem will not work.

## About this source tree

The repository previously contained only the exported web build. The source in
`src/`, `test/`, `scenes/`, `assets/` and `project.godot` was recovered from
`build/web/index.pck` and verified by re-exporting: **all 33 compiled scripts in
the rebuilt pack come out byte-identical to the shipped ones**, as do the
engine, icons and audio worklets.

Comments did not survive — the export stores a token stream, and comments
produce no tokens. Audio was only ever shipped QOA-compressed, so the WAVs are
decoded from that rather than original masters.

See [`tools/recover/README.md`](tools/recover/README.md) for the full method and
the verification numbers.
