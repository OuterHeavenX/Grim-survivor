# Grim Survivors

A grimdark vampire-survivors-lite built in Godot 4.7. Weapons fire on their own;
you move, dodge and pick up gems.

Eight stages, five minutes each, any of them selectable from the title screen.
A run is 5, 10, 15, 20 or 30 minutes -- that many five-minute stages, each
ending in a boss -- and finishing the last one is the victory.

Seven stages play by their own rule: Ashen Hollow's erupting cinder scars, the
Weeping Marsh's tides and islands, the Throne of Cinders' furnace lanes, the
Bone Desert's storms and bone piles, the Sunken Road's lantern convoy, the
Drowned Reach's tides and currents, and the Last Bastion's wards and siege.
Each has a scheduled event before its boss, and each boss has its own
multi-phase attack set. A fallen boss leaves a relic altar: rule-changing
relics weighted towards that stage's theme. Rotgrove keeps its original form.

Playable characters use original Blender civilian models: seven men in casual
clothes and six women in skirts, rendered as animated top-down sprites with
matching selection portraits. See [the roster and rebuild guide](art/civilians/README.md).

Thirteen playable survivors, one per weapon, so no two start the same way. Four
are bought with soul shards; the other nine are found — each stage hides a pair
of relics for one weapon, and collecting both unlocks whoever wields it. Any
weapon can also be carried in a two-slot loadout or picked up on level-up.

**Getting in is one tap.** The title screen is an animated altar holding the
selected survivor; BEGIN (CONTINUE after the first run) starts a run straight
away with the remembered stage and length. The stage/length picker sits behind
the descent button, and tapping the altar opens the survivor list. A first run
gets two short on-screen hints, opens with a ring of weak foes so the weapon
fires at once, and levels up within seconds (levels 1-4 need 3/6/10/16 XP,
then the original 5 + 6n curve). Choosing an upgrade throws nearby enemies back.

**The Daily Rite** is one stage and one seed per calendar day — the same for
everyone — five minutes long, never touching campaign progress. The end screen
can share a result line (system share sheet on phones, clipboard elsewhere),
and today's best rite is shown on the title button.

Six meta upgrade tracks bank across runs. Enemies scale with the stage, so later
ground is harder ground. Targets both
desktop and mobile web (portrait, 720×1280, on-screen joystick when a
touchscreen is present).

## Repository layout

```
project.godot          Godot project settings
export_presets.cfg     Web export preset (output: build/web/)
icon.svg               Project icon
upgrades_preview.png   Meta-upgrade screen art

scenes/main.tscn       Main scene — a single Node2D running src/main.gd
src/                   Game code; content Resource scripts in src/data/
data/                  Authored content (.tres): stages, bosses, enemies, relics...
test/                  Test harnesses and probes (see below)
assets/audio/          Sound effects and music (21 WAVs)
assets/packs/          Third-party CraftPix art packs. Carries a .gdignore, so
                       Godot skips it and none of it ships in the build —
                       copy a sprite out into assets/ to use it. See
                       assets/packs/README.md

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

## Content and stage systems

Content is authored as typed Godot Resources under `data/`, one `.tres` per
definition, with the scripts that define their shape in `src/data/`:

| Resource | Lives in | Describes |
| --- | --- | --- |
| `CharacterData` | `data/characters/` | survivors, unlock rule, start weapon, stats |
| `WeaponData` / `PassiveData` | `data/weapons/`, `data/passives/` | weapons, passives, evolutions |
| `EnemyData` | `data/enemies/` | stats, tags, water response, drop rule, behaviour script |
| `BossData` (+ `BossPhaseData`, `BossAttackData`) | `data/bosses/` | phases, attacks, hazard budget, warnings |
| `StageData` (+ `StageEventData`, `StageSpawnData`) | `data/stages/` | pool, boss, rule, schedule, relic weighting |
| `StageRuleData` | `data/rules/` | a stage rule's implementation and every number it uses |
| `RelicData` | `data/relics/` | run relics: tags, modifiers, optional effect script |
| `MetaUpgradeData` | `data/meta/` | meta upgrade tracks |

`data/game_content.tres` (`GameContentData`) references all of it and
validates it at startup — duplicate or empty ids, missing references, bad
boss thresholds, empty pools, out-of-order schedules, negative cooldowns,
unbounded spawns, broken evolutions, warnings under 0.65 s. Older code still
reads dictionary views (`GameManager.STAGES`, `CHAR_CLASSES`, `enemy.gd`'s
`TYPES`) built from the same resources.

Runtime pieces, all composed rather than switched on:

- `src/stage/` — `StageDirector` (one per stage: clock, events, intensity,
  special spawns, obstacles, cleanup), `StageRule` and the seven rules in
  `rules/`, `StageObjective`, and the props they place.
- `src/hazards/` — `TimedHazard` (warn → active → recover → linger, owned
  damage, shape + motion + icon telegraphs), `HazardShape`, and `SafeSpace`,
  which every pattern consults so none can close off all escape.
- `src/boss/` — `BossController` (phases, attack choice, hazard budget,
  enrage, punish windows, cleanup) and reusable `BossAttack`s in `attacks/`.
- `src/enemies/behaviors/` — one `EnemyBehavior` per enemy role.
- `src/combat/combat_rules.gd` — cross-weapon interactions with rate limits
  and a recursion guard; `src/relics/` — relic effects and the reward altar.
- `src/run_stats.gd` — the post-run report; `src/game_modifiers.gd` — the
  source-keyed stat modifiers boons, curses, relics and terrain share.

Each stage run is seeded (`GameManager.run_seed`, shown on the end screen),
so the same seed lays the same stage out.

Debug builds take a few keys during a run: **F5** +30 s, **F6** next
scheduled event, **F7** summon the boss, **F8** next boss phase, **F9** clear
stage hazards, **F10** print director and boss state.

Settings (pause menu or title → SETTINGS): screen shake, flashes, damage
numbers, hazard opacity, high-contrast warnings, reduced effects.

## Running it

Open the project folder in **Godot 4.7.2** and press play. Nothing else to
install.

The scripts in `test/` are harnesses that drive a live run and print
`PASS:`/`FAIL:` per check. `tools/run_tests.sh` runs every suite headlessly
(`GODOT=/path/to/godot ./tools/run_tests.sh`); CI runs the same script.

| Suite | Covers |
| --- | --- |
| `test_chars`, `test_elite`, `test_gear`, `test_joy`, `test_stages`, `test_ui` | the original game |
| `test_content` | catalog validation, adapters, save migration, settings |
| `test_stage_rules` | all seven stage rules, events, hazard timing, safe space, cleanup, seeding |
| `test_bosses` | every boss phase and attack, warnings, budget, signatures, cleanup |
| `test_interactions` | cross-weapon interactions, relics, proc limits, the altar |
| `test_enemies` | the eight new enemy roles |
| `test_run` | a full 30-minute campaign run to victory, save and title |

`probe_balance` and `probe_perf` are measurements, not tests. `probe_perf`
times script and physics work in a worst-case late encounter headlessly; it
does not measure rendering or the web build.

## Building the web export

```sh
godot --headless --path . --export-release "Web"
```

Writes to `build/web/`. The preset uses two inputs from `web/` (which carries a
`.gdignore`, so none of it is packed into the game):

- `web/godot.web.template_release.wasm32.nothreads.zip` — a slim export
  template: Godot 4.7.2 built with 3D, the advanced text server and every
  module this game does not use compiled out. It halves the engine download
  (wasm 39.5 MB → 20.3 MB; the whole page went from ~50 MB to ~27 MB).
  Rebuild it with `tools/build_web_template.sh`; if the game starts using
  something that script disables (3D nodes, RegEx, runtime SVG, networking…),
  re-enable that module first.
- `web/shell.html` — the page around the canvas: a branded loader with real
  download progress and rotating tips, and an ENTER button that lifts the veil
  once the game is running. That tap is the user gesture browsers require for
  sound, so the altar's music starts with the reveal. It also carries the
  social-preview meta tags; `web/og-image.png` is copied next to the export by
  the Pages workflow. That directory carries a `.gdignore` so Godot does not
import its own output back into the project — without it, the export sweeps
copies of its own icons into the pack.

The preset builds the single-threaded Web variant, so the output needs no
cross-origin isolation headers and runs on any static host. It does have to be
served over HTTP, though — opening `index.html` off the filesystem will not
work. To try it locally:

```sh
python3 -m http.server -d build/web 8000   # then open http://localhost:8000
```

## Deployment

`.github/workflows/pages.yml` publishes `build/web/` to GitHub Pages on every
push to `main` that touches it, and can be run by hand from the Actions tab.
It uploads the committed export as-is; nothing is compiled in CI, so it needs
neither Godot nor the export templates.

For this to do anything, **Pages must be set to deploy from GitHub Actions**
(otherwise GitHub's own branch deployment publishes the repository root as
well, and the two race):
Settings → Pages → Build and deployment → Source → *GitHub Actions*. Left on
"Deploy from a branch" the workflow runs and fails at the deploy step.

So the release loop is: export locally, commit `build/web/`, push to `main`.

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
