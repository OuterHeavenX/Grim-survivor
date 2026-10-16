# Grim Survivors — Seven-Stage Expansion Master Prompt

## Role and objective

You are the lead Godot 4.7.2 gameplay engineer and technical designer working inside the existing **Grim Survivors** repository. Expand the seven remaining stages into mechanically distinct, polished encounters while preserving the current game, save compatibility, campaign structure, mobile-web target, and established grimdark style.

The seven stages in scope are:

1. Ashen Hollow
2. The Weeping Marsh
3. Throne of Cinders
4. The Bone Desert
5. The Sunken Road
6. The Drowned Reach
7. The Last Bastion

Treat Rotgrove as the reference slice for the intended architecture and quality bar if such a slice exists when work begins. If it does not exist, build the shared systems needed by these seven stages without inventing dependencies on an absent implementation. Do not silently rewrite unrelated systems.

The finished expansion must make every stage identifiable through gameplay—not merely its palette, enemy pool, or boss name. Each stage needs a signature environmental rule, a stage event, a distinct boss encounter, meaningful rewards, readable telegraphs, mobile-friendly controls, and automated coverage.

## Current project facts

- Engine: Godot 4.7.2, GDScript, GL Compatibility renderer.
- Main scene: `res://scenes/main.tscn`.
- Primary orchestration currently lives in `src/main.gd` and `src/game_manager.gd`.
- The game supports desktop and portrait mobile web at 720×1280.
- Runs contain one or more five-minute stages. Each stage ends with a boss.
- Existing content includes 13 survivors, 13 weapons, seven passives, weapon evolutions, elites, relic-based unlocks, campaign/free-play modes, soul shards, and meta upgrades.
- Weapon, passive, and evolution definitions have begun moving into typed Godot Resources under `data/` and `src/data/`. Preserve and extend that architecture.
- `build/web/` is generated output. Never hand-edit it.
- Preserve existing uncommitted user work. Inspect `git status` and diffs before editing.

## Non-negotiable engineering rules

1. Work incrementally. Complete and validate one phase before starting the next.
2. Do not break existing save files. Missing new fields must receive safe defaults. Never erase unknown or future-facing save keys.
3. Keep current public behavior compatible while migrating data. Temporary dictionary adapters are acceptable; new systems should consume typed Resources directly where practical.
4. Store content definitions in `.tres` Resources. Keep runtime state in nodes/components, not shared Resource instances.
5. Prefer composition for hazards, objectives, boss attacks, status effects, and stage rules. Do not turn `main.gd`, `enemy.gd`, or `game_manager.gd` into larger switch statements.
6. Every damaging mechanic needs a clear warning, active state, recovery state, collision policy, and cleanup path.
7. All stage objects and hazards must clean themselves up during stage transitions, restart, death, victory, and return to title.
8. Respect existing caps for enemies, pickups, and hazards. Add bounded pools/caps for any new spawned object type.
9. Keep gameplay legible on a 720×1280 portrait viewport. Never rely exclusively on color; use shape, animation, iconography, or motion as a second signal.
10. Support keyboard, controller, and touch input. Do not add required precision clicking.
11. Maintain the current five-minute cadence. Stage mechanics may intensify over time but must not delay the boss indefinitely.
12. Use deterministic seeded randomness for stage event placement where feasible. Record the seed in the post-run summary or debug output.
13. Do not introduce paid assets, unlicensed content, plugins, or network dependencies.
14. Do not regenerate or commit the web export until source validation is complete.
15. Comment design intent and invariants, not obvious syntax.

## Shared target architecture

Complete the data separation before multiplying content. Add typed Resources as needed:

- `CharacterData`: id, display name, flavor, unlock rule, starting weapon, base stats, portrait/sprite references, optional innate trait.
- `StageData`: id, display name, theme, enemy pool, boss reference, relic pool, stage-rule reference/configuration, event schedule, music profile, environmental colors and assets.
- `EnemyData`: id, base stats, XP value, collision radius, sprite references, behavior profile, tags, status resistances, drop profile.
- `BossData`: base enemy data plus phases, attack set, thresholds, arena modifiers, reward table, and presentation metadata.
- `StageRuleData`: rule id, configurable timing and intensity values, telegraph settings, safe-zone behavior, spawn caps, and accessibility overrides.
- `RelicData`: id, rarity, tags, description, rule modifiers, compatibility requirements, icon, and discovery state.
- `MetaUpgradeData`: id, costs, per-rank values, formatting strings, maximum rank, and behavior hook.

Create a central content catalog Resource that references these definitions. It must validate on startup or through a dedicated validation test:

- Duplicate and empty IDs
- Missing referenced weapons, passives, enemies, bosses, stages, relics, and resources
- Invalid boss phase thresholds
- Empty enemy pools
- Invalid stage schedules
- Invalid ranges, negative cooldowns, and unbounded spawn counts
- Broken evolution requirements
- Characters without valid starting weapons

Introduce small runtime contracts/components instead of stage-specific code scattered through the main loop:

- `StageDirector`: owns stage time, scheduled events, intensity, and stage-rule lifecycle.
- `StageRule`: base interface for setup, tick, intensity change, boss transition, cleanup, and debug state.
- `StageObjective`: optional objective lifecycle and HUD progress.
- `Hazard`: telegraph/active/recovery lifecycle with damage ownership and pooling/cap support.
- `BossController`: phase transitions, attack selection, cooldowns, enrage behavior, and cleanup.
- `BossAttack`: reusable attack implementation with telegraph metadata.
- `RunStats`: damage by weapon, damage taken, healing, kills by enemy, elites, bosses, pickups, stage events, and completion time.

Do not over-engineer a generic framework before a real stage uses it. Extract a reusable component when at least two stages need the behavior or when the lifecycle is safety-critical.

## Shared gameplay requirements

Every stage must contain:

- One passive environmental rule active throughout most of the stage
- One scheduled event or temporary escalation before the boss
- At least one stage-specific combat interaction involving enemies, movement, hazards, or pickups
- A unique boss behavior set, even when an existing visual base is reused temporarily
- At least three boss attacks, including one movement-pressure attack and one positional attack
- At least two boss phases, with a readable transition at 50% health or another documented threshold
- A stage-specific reward or relic weighting
- HUD messaging that is short enough for mobile
- Audio/visual telegraphs with accessibility fallbacks
- Debug commands or test hooks to advance time, trigger the event, summon the boss, change phases, and clean up

Boss attacks must not overlap into unavoidable damage. Define a per-boss attack budget controlling simultaneous hazards, minimum safe area, and minimum reaction time. Normal difficulty should provide at least 0.65 seconds of warning for major attacks; faster difficulty tiers may reduce this only within accessible limits.

## Phase 1 — Ashen Hollow: Embers Beneath the Ash

### Stage identity

Ash falls continuously and periodically forms **cinder scars** on the ground. Scars begin as visible dark cracks, glow during warning, then erupt. Recent scars cool into temporary safe ground that cannot immediately erupt again.

### Timeline

- 0:00–1:00: sparse single scars teach the rule.
- 1:00–3:00: small linked patterns appear away from the player, then begin predicting movement.
- 3:00–4:30: alternating eruption bands create movement lanes.
- 4:30: **Ashfall Event**—visibility drops slightly, eruption frequency increases, and cooled safe ground becomes important.
- 5:00: boss arrival stops new random patterns and transfers control to the boss attack budget.

### Boss: Herald of Vorgath

- Phase 1: radial ember volley, targeted cinder scar, sweeping ash cone.
- Phase 2: breaks its staff or mask, ignites existing scars, and uses a slow rotating safe-gap ring.
- Enrage protection: increased cadence, not raw unavoidable area coverage.
- Reward weighting: fire, projectile, and retaliation relics.

### Acceptance criteria

- Eruption warnings are visible through fog and enemy crowds.
- The player always has a reachable safe region.
- Stage-generated scars stop and clean up during the boss transition.
- Tests verify warning harmlessness, active damage, cooldown ground, cleanup, and phase transition.

## Phase 2 — The Weeping Marsh: Rising Mire

### Stage identity

The marsh cycles between low and high water. High water slows actors outside raised islands. Enemies have explicit water-response tags: bog creatures ignore the slow; heavy enemies resist it; ordinary enemies are affected less than the player to avoid trivial kiting.

### Timeline

- 0:00–1:15: low water with clearly marked islands.
- 1:15: first tide warning and short high-water cycle.
- 2:00–4:00: cycles become longer; drifting soul-lights mark the next safe islands.
- 4:15: **Mire Bloom Event**—toxic blooms appear in water and can be detonated by fire damage, harming enemies and players with separate tuned values.
- 5:00: tide stabilizes for the boss arena, leaving several usable islands.

### Boss: Maw of the Mire

- Phase 1: telegraphed lane charge, toxic spit pools, tongue pull with a breakable tether.
- Phase 2: submerges and resurfaces at marked locations, destroys one island temporarily, and summons mire growths that heal it until destroyed.
- Reward weighting: poison, healing, slowing, and area-control relics.

### Acceptance criteria

- Water state is readable without relying solely on tint.
- Slow modifiers compose correctly with character speed and existing passives.
- Fire/bloom interaction cannot recursively detonate forever.
- Boss submerge never selects an invalid or inaccessible location.

## Phase 3 — Throne of Cinders: The Furnace Court

### Stage identity

Ancient furnace mouths around the arena fire **heat lanes**. Each furnace telegraphs direction and timing. Crossing behind an active furnace offers a temporary damage or haste boon, encouraging deliberate risk.

### Timeline

- 0:00–1:00: one furnace at a time.
- 1:00–3:00: opposing furnaces create moving corridors.
- 3:00–4:20: elites can activate dormant furnaces until killed.
- 4:20: **Royal Decree Event**—four furnaces activate in a readable sequence, leaving one rotating safe quadrant.
- 5:00: furnaces become boss-controlled and obey the boss attack budget.

### Boss: The Cinder King

- Phase 1: sword-wave fan, furnace command, delayed meteor marks.
- Phase 2: crown ignition; the boss leaves a short-lived flame trail and alternates arena-wide furnace patterns with punishable recovery windows.
- Reward weighting: burn, explosion, cooldown, and high-risk damage relics.

### Acceptance criteria

- Heat lanes have clear direction, warning, activation, and recovery animations.
- The risk-zone boon cannot stack without a defined cap and refresh rule.
- Furnace and meteor patterns never eliminate all safe space.
- Tests cover furnace sequencing, boon limits, meteor timing, and boss recovery windows.

## Phase 4 — The Bone Desert: Ossuary Storm

### Stage identity

Periodic bone storms reduce distant visibility and push loose pickups. Large fossil ribs provide wind shelter but constrain movement. Killing skeletal enemies near bone piles may add fragments that can be shattered for XP or used by necromancers.

### Timeline

- 0:00–1:00: light wind communicates direction.
- 1:00–3:00: short storms and a few shelter ribs.
- 3:00–4:15: necromancer waves compete with the player for bone piles.
- 4:15: **Ossuary Storm Event**—sustained wind, enhanced bone-pile rewards, and more dangerous revival pressure.
- 5:00: wind drops, revealing the boss arena and accumulated bone piles.

### Boss: The Pale Herald

- Phase 1: bone spear lines, skeletal hand cages, and corpse reanimation.
- Phase 2: assembles a bone armor shell from nearby piles. Destroy armor segments to expose weak points and prevent enhanced attacks.
- Reward weighting: piercing, summons, critical hits, and corpse/kill-trigger relics.

### Acceptance criteria

- Wind affects pickups predictably without pushing them out of arena bounds.
- Shelters remain readable during reduced visibility.
- Revived enemies do not grant repeated XP, shards, kills, or drops unless explicitly designed and capped.
- Boss armor state and weak points are visible at mobile scale.

## Phase 5 — The Sunken Road: The Procession

### Stage identity

The run follows a slowly moving **lantern convoy** along a ruined road. Remaining near the light grants visibility and a small defensive benefit; moving ahead finds shrines and treasure but increases ambush risk. The convoy cannot permanently die or soft-lock the run.

### Timeline

- 0:00–1:00: convoy movement and aura are introduced.
- 1:00–3:00: roadblocks pause the convoy until nearby wardens are defeated.
- 3:00–4:15: branching detours offer optional shrines with curse/reward choices.
- 4:15: **Broken Bridge Event**—hold a marked area while the convoy crosses, with bounded waves and a completion timer.
- 5:00: convoy reaches the boss gate and forms the boss arena boundary.

### Boss: Warden of the Road

- Phase 1: shield wall, directional slam, and summoned roadblock pillars.
- Phase 2: abandons the shield, charges between pillars, and creates shockwave gaps the player must read.
- Reward weighting: armor, movement, knockback, and objective-based relics.

### Acceptance criteria

- Convoy position cannot leave arena bounds or separate permanently from the player.
- Optional detours remain optional; missing them cannot block the boss.
- Objective progress is clearly displayed and pauses correctly with the game.
- Boss pillars do not trap the player in invalid geometry.

## Phase 6 — The Drowned Reach: The Dead Tide

### Stage identity

The tide alternates between exposed seabed and flooded ground. Low tide reveals treasure, relic traces, and dangerous dormant enemies. High tide awakens spectral currents that move in visible paths and carry enemies, pickups, and the player at separately tuned strengths.

### Timeline

- 0:00–1:00: low tide and exposed treasure markers.
- 1:00–3:00: short high-tide currents teach directional movement.
- 3:00–4:15: drowned enemies awaken when exposed caches are opened.
- 4:15: **Dead Tide Event**—currents reverse twice and spectral ships pass across the background before firing clearly marked broadsides.
- 5:00: water forms a circular boss arena with rotating current lanes.

### Boss: The Drowned Maw

- Phase 1: water jets, anchor drops connected by damaging chains, and summoning drowned hands.
- Phase 2: whirlpool center pulls actors inward while rotating safe currents provide escape routes; destroying anchors weakens the pull.
- Reward weighting: magnetism, chaining, cold, and pickup-conversion relics.

### Acceptance criteria

- Current forces compose with movement rather than overriding input.
- Opened caches cannot respawn rewards after tide transitions.
- Anchor chains are visually and mechanically consistent.
- Whirlpool strength has a hard cap and always permits escape with base movement speed.

## Phase 7 — The Last Bastion: Siege of the Ashen Sovereign

### Stage identity

This is the campaign culmination. Three ruined bastion wards surround the arena. Players activate and defend them to gain temporary support effects. Losing a ward changes the run but never makes victory impossible. The stage remixes earlier mechanics in controlled pairs rather than stacking everything simultaneously.

### Timeline

- 0:00–1:15: choose the first ward, defining one temporary stage boon.
- 1:15–3:00: defend a second ward while one earlier-stage hazard appears in a simplified form.
- 3:00–4:15: elite commander waves target active wards.
- 4:15: **Final Siege Event**—surviving wards fire on siege portals while the player closes them. Each closed portal reduces boss reinforcement strength.
- 5:00: surviving wards and closed portals alter the final boss encounter without making any outcome mandatory.

### Boss: The Ashen Sovereign

- Phase 1: disciplined sword arcs, command banners that buff adds, and targeted bastion bombardment.
- Phase 2: destroys the throne armor, incorporates one attack motif from two prior bosses, and exposes a punishable core after major attacks.
- Final stand at low health: brief, capped escalation with no new rules and no healing reset.
- Reward: campaign completion, substantial soul shards, a guaranteed high-tier relic unlock, and a cosmetic or challenge marker rather than mandatory permanent power.

### Acceptance criteria

- Ward outcomes persist only for the current run unless explicitly recorded as achievements.
- Simplified legacy hazards use the shared implementations and remain within the attack budget.
- Portal completion changes reinforcement counts deterministically.
- The final phase is dramatic but remains readable on low-end mobile hardware.
- Victory, campaign unlocks, rewards, saving, and return-to-title behavior receive end-to-end tests.

## Cross-stage enemies and interactions

Add new enemy roles gradually and share them where thematic:

- Cultist healer: channels a visible beam; interruption rules are explicit.
- Necromancer: consumes corpses or bone piles; resurrection rewards are protected from farming.
- Shield bearer: directional protection with readable flanking behavior.
- Ranged cultist: fires telegraphed lines and maintains a minimum distance.
- Burrower: marks emergence location and predicts movement with limited lead.
- Banner carrier: buffs a bounded group and exposes the banner after death.
- XP leech: steals loose gems but drops stored value when killed.
- Mimic: uses chest language but includes a fair visual tell and never replaces mandatory rewards.

Every enemy needs an `EnemyData` resource, behavior test, sprite fallback, drop rule, stage assignments, and performance cap.

## Relics and build interactions

Add a first set of 14–21 rule-changing relics, with at least two strongly associated with each stage. Avoid pure percentage bonuses unless they enable a clear build identity. Support tags such as `fire`, `cold`, `poison`, `projectile`, `orbit`, `summon`, `armor`, `movement`, `pickup`, `corpse`, and `objective`.

Implement at least these cross-weapon interactions:

- Fire damage ignites miasma clouds with a capped explosion.
- Heavy impacts shatter frozen enemies.
- Scythe harvests can trigger raven effects.
- Orbiting blades can conduct chain lightning at a bounded rate.
- Burning targets receive stronger comet targeting weight.
- Bone Lance marks pierced targets for projectile follow-up damage.

Prevent recursive proc loops. Every triggered interaction needs source attribution, a cooldown or generation limit, and automated tests.

## Presentation and usability

- Add stage-introduction cards naming the environmental rule in one short sentence.
- Add boss arrival, phase-transition, and defeat presentation without long control lockouts.
- Add off-screen indicators for boss, elites, stage objective, chest, and relic targets.
- Add settings for screen shake, flashes, damage numbers, hazard opacity, and high-contrast telegraphs.
- Use layered music states if supported: exploration, escalation, boss, low-health/final phase.
- Add a post-run report showing weapon damage, evolved state, damage taken, healing, stage completion, boss time, relics, and run seed.

## Performance requirements

- Profile representative late-stage encounters on the web target.
- Avoid per-frame full-tree group scans in new systems; cache or maintain registries where safe.
- Reuse draw calls and simple primitives when possible.
- Bound particles, decals, hazards, summons, projectiles, revived enemies, and damage labels.
- Do not use expensive navigation for simple horde movement unless measurements justify it.
- Target stable play under the existing enemy cap and worst-case boss hazard pattern.
- New effects must degrade gracefully when reduced-effects mode is enabled.

## Testing and validation

Preserve all existing tests and add focused harnesses for:

- Content catalog validation
- Resource loading and legacy adapters
- Save migration/default values
- Each stage rule lifecycle
- Each scheduled stage event
- Hazard warning/active/recovery timing
- Damage ownership and invulnerability interaction
- Cleanup on transition, restart, death, victory, and title return
- Each boss phase and attack budget
- Safe-space guarantees for arena patterns
- Objective success/failure and anti-soft-lock behavior
- Relic proc limits and synergy recursion prevention
- Touch/controller navigation for new UI
- Post-run statistics accuracy

At the end of every phase:

1. Run `godot --headless --path . --editor --quit`.
2. Run all existing relevant harnesses.
3. Run the new phase-specific harnesses.
4. Run `git diff --check`.
5. Review `git status --short` and ensure no generated or temporary runner files remain.
6. Perform a short playable smoke test when a graphical environment is available.
7. Report changed files, behavior delivered, test results, known limitations, and the next phase.

Do not claim visual quality, mobile performance, or browser compatibility from static inspection alone. State exactly what was tested.

## Completion definition

The expansion is complete only when:

- All seven scoped stages have distinct, functioning environmental mechanics and events.
- All seven bosses have unique multi-phase behavior and readable attack patterns.
- New definitions are authored through typed Godot Resources.
- Existing saves and game modes continue to work.
- No stage can soft-lock due to an objective, hazard, boss state, or inaccessible spawn.
- Hazards and spawned objects remain within documented caps and clean up correctly.
- Existing and new automated tests pass.
- A complete 30-minute run can transition through stages, bosses, rewards, victory, saving, and return to title.
- Desktop and mobile-web controls remain usable.
- The post-run report accurately describes the build and results.
- Source changes are clean and reviewable; generated web output is updated only as a final deliberate release step.

## Execution behavior

Begin by inspecting the repository, current diffs, tests, and the partially completed Resource migration. Produce a short implementation map identifying reusable systems and likely file changes. Then implement Phase 1. Continue phase by phase without asking for routine decisions. Pause only for a genuine product choice, unavailable required asset, destructive action, external credential, or scope conflict.

Keep each phase independently playable. Prefer a smaller, polished, verified implementation over broad unfinished scaffolding. Never report a phase complete until its acceptance criteria and tests are satisfied.
