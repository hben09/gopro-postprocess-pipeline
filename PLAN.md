# GoPro Post-Processing Pipeline — Implementation Plan

## Context

Automate the post-processing of GoPro Hero 12 footage (5.3K 30fps, GP-Log color profile) on macOS. The pipeline stabilizes footage via Gyroflow, applies a .cube LUT for color grading, and exports to H.265 for space-efficient high-quality output. Originals are moved to an archive folder after successful processing.

**Key quality decision:** Gyroflow outputs to ProRes 422 (near-lossless intermediate), then FFmpeg does the single lossy encode (H.265 + LUT). This avoids double lossy compression.

## Progress

| Step | File | Status |
|------|------|--------|
| 0 | `CLAUDE.md` | Done |
| 1 | `README.md` | Done |
| 2 | `PLAN.md` | Done |
| 3 | `config.sh` | Pending |
| 4 | `install.sh` | Pending |
| 5 | `process.sh` | Pending |
| 6 | `presets/.gitkeep`, `luts/.gitkeep` | Pending |

## File Structure

```
gopro-postprocess-pipeline/
├── CLAUDE.md           # Claude Code project context
├── PLAN.md             # This file — implementation plan & progress
├── README.md           # Setup + usage docs
├── process.sh          # Main CLI script
├── config.sh           # User-editable settings (paths, quality, encoder)
├── install.sh          # Dependency checker (Homebrew, FFmpeg, Gyroflow)
├── presets/             # User places .gyroflow preset here
│   └── .gitkeep
└── luts/               # User places .cube LUT here
    └── .gitkeep
```

## Implementation Details

### `config.sh` — Configuration

All user-tunable variables in one file, sourced by `process.sh`:

| Variable | Purpose | Default |
|----------|---------|---------|
| `GYROFLOW_BIN` | Path to Gyroflow binary | `/Applications/Gyroflow.app/Contents/MacOS/Gyroflow` |
| `GYROFLOW_PRESET` | Path to `.gyroflow` preset file | `presets/gopro-hero12-default.gyroflow` |
| `LUT_FILE` | Path to `.cube` LUT file | `luts/*.cube` (first found) |
| `ENCODER` | H.265 encoder | `hevc_videotoolbox` |
| `VT_QUALITY` | VideoToolbox quality (1-100) | `65` |
| `X265_CRF` | libx265 CRF (0-51) | `20` |
| `ARCHIVE_DIR_NAME` | Subdirectory for moved originals | `originals` |
| `DELETE_INTERMEDIATE` | Remove ProRes temps after encode | `true` |

### `install.sh` — Dependency Setup

Idempotent checker:
1. Check Homebrew installed — print install URL if missing
2. Check `ffmpeg` on PATH — `brew install ffmpeg` if missing
3. Verify `hevc_videotoolbox` encoder available
4. Check Gyroflow.app exists at configured path
5. Print summary

### `process.sh` — Main Pipeline

**Usage:** `./process.sh /path/to/footage [/path/to/output]`

Accepts a directory of `.MP4` files or a single file. Output defaults to `<input_dir>/processed/`.

#### Stage 1: Gyroflow Stabilization

```bash
"$GYROFLOW_BIN" "$input_file" \
  --preset "$GYROFLOW_PRESET" \
  -p "{ 'codec': 'ProRes', 'bitrate': 0, 'use_gpu': true, 'audio': true }" \
  -t "_stabilized" \
  -f
```

Output: `{basename}_stabilized.mov` (ProRes 422 intermediate), written alongside the input file.

> **Note:** Gyroflow has no output directory flag — it always writes next to the input file. After Gyroflow finishes, `process.sh` must move the intermediate from `${input_dir}/${basename}_stabilized.mov` to the working/output directory for Stage 2.

#### Stage 2: LUT + H.265 Encode

```bash
# Hardware encoder (default)
ffmpeg -i "$intermediate" \
  -vf "lut3d='$LUT_FILE':interp=tetrahedral" \
  -c:v hevc_videotoolbox -q:v "$VT_QUALITY" \
  -tag:v hvc1 -c:a aac -b:a 256k \
  -movflags +faststart "$output_file"
```

- `-tag:v hvc1` — Apple/QuickTime HEVC compatibility
- `-movflags +faststart` — fast playback start
- Tetrahedral interpolation — best quality for 3D LUTs

#### Stage 3: Cleanup

- Verify output exists and is non-zero size
- Delete ProRes intermediate (if `DELETE_INTERMEDIATE=true`)
- Move original to `<input_dir>/originals/`

#### Error Handling

- `set -euo pipefail` with per-file error isolation
- Failed files: intermediate kept, original NOT moved
- Ctrl+C trap for graceful cleanup of partial files
- End-of-run summary: success/fail counts, list of failures

#### GoPro Chapter Files

GoPro splits recordings >12 min into chapters (`GX010042.MP4`, `GX020042.MP4`, etc.). Each is processed independently — no auto-concatenation since each has its own gyro data.

## Verification

1. Run `./install.sh` — confirm deps detected correctly
2. Place a `.cube` LUT in `luts/` and a `.gyroflow` preset in `presets/`
3. Run `./process.sh /path/to/single/GoPro.MP4` — verify:
   - ProRes intermediate created then cleaned up
   - Final `.mp4` output has LUT applied (colors look correct)
   - Original moved to `originals/` subfolder
   - File size is smaller than source
4. Run on a folder with multiple files — verify batch processing, error isolation, and summary output
