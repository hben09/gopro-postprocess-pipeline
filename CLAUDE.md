# GoPro Post-Processing Pipeline

## Overview

Automated pipeline for GoPro Hero 12 footage: Gyroflow stabilization, LUT color grading, and H.265 export. Runs on macOS via CLI.

## Architecture

3-stage per-file pipeline:

1. **Gyroflow** - Stabilize using gyro data, output to ProRes 422 HQ intermediate (GPU accelerated, audio preserved)
2. **FFmpeg** - Optional .cube LUT (tetrahedral interpolation, `APPLY_LUT=false` by default) + optional resolution scaling + 10-bit H.265 encode (main10 profile, bt709 color space, audio passthrough)
3. **Cleanup** - Delete intermediate, move original to archive

ProRes intermediate between stages avoids double lossy encoding (only one lossy encode at the final H.265 step).

## Key Files

- `process.sh` - Main pipeline script. Usage: `./process.sh [/path/to/footage] [/path/to/output]`
- `config.sh` - All user-tunable settings (paths, encoder, quality). Sourced by process.sh.
- `install.sh` - Dependency checker/installer (Homebrew, FFmpeg, Gyroflow verification)
- `logging.sh` - Shared logging utilities (colors, log functions, timers). Sourced by process.sh and install.sh.
- `1_unprocessed/` - Drop raw GoPro footage here (default input directory)
- `2_processed/` - Pipeline output lands here (default output directory)
- `3_archive/` - Originals are moved here after successful processing
- `presets/` - User places `.gyroflow` preset files here
- `luts/` - User places `.cube` LUT files here

## Tech Stack

- **Shell:** Bash with `set -euo pipefail`
- **Gyroflow:** CLI mode of the GUI app (`/Applications/Gyroflow.app/Contents/MacOS/Gyroflow`)
- **FFmpeg:** Via Homebrew. H.265 encoding via `hevc_videotoolbox` (hardware) or `libx265` (software)
- **Platform:** macOS only (uses Apple VideoToolbox for hardware encoding)

## Conventions

- Config is sourced (`source config.sh`), not parsed
- Per-file error isolation: failures skip to next file, don't abort batch
- GoPro chapter files (GX01xxxx, GX02xxxx) processed independently (each has own gyro data)
- Output uses `-tag:v hvc1` for Apple/QuickTime compatibility
- `-movflags +faststart` on all outputs
- Already-processed files are skipped (enables resumable batches)
- Case-insensitive `.mp4` matching via `nocaseglob`
- Interactive preset selection when multiple `.gyroflow` files exist in `presets/` (auto-selects if only one)

## User Setup

- GoPro Hero 12, 5.3K 30fps, GP-Log color profile
- User-provided `.cube` LUT file in `luts/`
- User-created `.gyroflow` preset in `presets/` (exported from Gyroflow GUI)
