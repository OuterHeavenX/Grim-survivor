# Design QA — Survivor Altar

- Source visual truth: `C:\Users\jimmy\.codex\generated_images\01a142ce-42c5-7120-b253-279f2272aaf6\exec-a7d319fc-7032-480e-8cff-8dd8604893c4.png`
- Implementation screenshot: `C:\Users\jimmy\AppData\Local\Temp\grim-survivors-altar-qa\title00000002.png`
- Viewport / CSS size: 720 × 1280 logical pixels
- Source pixels: 941 × 1664; implementation pixels: 720 × 1280. Compared at equal portrait aspect after visual normalization; no device frame or browser chrome.
- State: title screen, default Hooded Rogue, first campaign stage, Ashen sigil.

## Full-view comparison evidence

The implementation preserves the source hierarchy: branded masthead and currency, campaign progress, a dominant framed survivor altar, primary Continue action, next-unlock teaser, and four persistent collection/navigation destinations. The live game uses the project's authored portrait and ground texture rather than replacing its established art style with the mockup's generated realism.

## Focused region comparison evidence

The top bar and bottom navigation were inspected at full resolution because they contain the smallest type and tightest controls. A first capture showed the sound/settings controls and fourth navigation item clipped at the right edge. Their widths and title scale were reduced, then recaptured; all controls now fit inside the 26 px safe margins with readable labels and 60–72 px touch heights. The central portrait is sharp at its native scale and has no halo or distorted crop.

## Required fidelity surfaces

- Fonts and typography: Godot's existing UI font is retained. Display, label, and utility tiers are distinct and legible; no truncation remains.
- Spacing and layout rhythm: 26 px outer margins, a dominant flexible hero region, 92 px primary action, and evenly sized bottom navigation create a stable vertical rhythm at 720 × 1280.
- Colors and tokens: near-black ash background, warm bone headings, gold progression/action accents, violet soul currency, and sigil-colored hero borders match the selected direction.
- Image quality and assets: real project portrait and ground assets are used at correct aspect ratio. No emoji, placeholder art, inline SVG, or code-drawn substitute replaces visible target imagery.
- Copy and content: campaign progress, selected survivor/weapon, best run, currency, next unlock, and collection destinations are all live game data.

## Findings

No actionable P0, P1, or P2 findings remain.

## Comparison history

1. P1: top utility controls and the UNLOCKS navigation item overflowed the right edge in the first implementation capture. Fixed by compacting the masthead and utility controls and reducing each navigation item to 154 px. Post-fix evidence is the implementation screenshot above.

## Follow-up polish

- P3: a dedicated illustrated altar background could bring the atmosphere closer to the cinematic mockup while retaining the game's existing character art direction.

## Implementation checklist

- [x] Core hierarchy matches the selected concept.
- [x] Persistent live progression data is visible.
- [x] All primary controls fit the target viewport and meet touch-size expectations.
- [x] Native assets remain sharp and correctly cropped.
- [x] Keyboard/controller focus starts on Continue.

final result: passed
