# Source recovery tooling

These scripts reconstructed `src/`, `test/`, `scenes/`, `assets/` and
`project.godot` from `build/web/index.pck`, back when the repository contained
only the exported web build and no source.

They are kept for provenance: they let anyone re-derive the source tree from the
shipped pack and check it against what is committed here. Nothing in the game
depends on them — delete the directory if you don't want it.

## Scripts

| Script | Purpose |
| --- | --- |
| `pck_extract.py` | Unpacks a Godot 4 `.pck` (pack format 4) to a directory. |
| `gdc2gd.py` | Reconstructs GDScript source from a `.gdc` binary token buffer. |
| `gdtokens.py` | GDScript token-type table and literal spellings. |
| `variant.py` | Decoder for Godot's binary `Variant` encoding. |
| `projbin.py` | Reads the `ECFG` block of `project.binary`. |
| `mkproject.py` | Renders those settings back out as a text `project.godot`. |
| `qoa.py` | Decodes the QOA payload of an `AudioStreamWAV` to a 16-bit PCM WAV. |

Requires Python 3 and `zstandard` (`pip install zstandard`).

## Re-deriving the tree

```sh
python3 tools/recover/pck_extract.py build/web/index.pck /tmp/pck
python3 tools/recover/gdc2gd.py /tmp/pck/src/player.gd.gdc      # -> stdout
python3 tools/recover/mkproject.py /tmp/pck/project.binary      # -> stdout
```

`.tscn`, `.png` and the QOA payloads were extracted by loading the exported
binaries in Godot 4.7.2 headless and re-saving them (`ResourceSaver.save`,
`Image.save_png`, `AudioStreamWAV.data`); `qoa.py` then turned the QOA payloads
into WAV files.

## How the result was verified

The recovered tree was re-exported with Godot 4.7.2 using `export_presets.cfg`
and the output compared against the build committed in `build/web/`:

- all 33 compiled scripts in the rebuilt pack are **byte-identical** to the
  originals, so the recovered GDScript is token-for-token the same code;
- `index.wasm`, `index.js`, `index.png`, both icons and both audio worklets are
  byte-identical;
- `index.html` differs only in the `fileSizes` value it embeds for `index.pck`;
- `index.pck` differs only in the audio, which is re-encoded (see below).

## What could not be recovered

- **Comments and blank-line placement.** The export stores a token stream;
  comments produce no tokens. Formatting here is regenerated from the recorded
  line and column of each token, so statements sit on their original lines.
- **Original audio masters.** The pack only carries QOA-compressed audio, which
  is lossy. The WAVs in `assets/audio/` are decoded from it, so 13 of 21 come
  back bit-identical through a re-encode and the rest average ~87 dB SNR.
- **`export_presets.cfg`.** Not stored in the pack. It was reconstructed to
  reproduce the committed build, and does so exactly.
