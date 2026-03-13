# GoPro Post-Processing Pipeline

Automated pipeline for processing GoPro footage on macOS. Stabilizes with Gyroflow, applies a color LUT, and exports to space-efficient H.265.

> **Status:** Ready to use. Drop footage in `unprocessed/`, run `./process.sh`, pick up results from `processed/`.

## Prerequisites

- **macOS** (uses Apple VideoToolbox for hardware H.265 encoding)
- **[Gyroflow](https://gyroflow.xyz/)** installed in `/Applications/`
- **FFmpeg** (installed via the included setup script)
- A `.cube` LUT file for color grading
- GoPro Hero 12 footage shot in GP-Log (flat) color profile

## Setup

### 1. Install dependencies

```bash
./install.sh
```

This checks for Homebrew, installs FFmpeg if needed, and verifies Gyroflow is available.

### 2. Create a Gyroflow preset

1. Open Gyroflow
2. Load a representative GoPro Hero 12 video
3. Configure your stabilization settings:
   - Select the correct lens profile (Hero 12, your resolution/fps)
   - Adjust smoothness, horizon lock, rolling shutter correction as desired
4. Click the arrow next to the Export button and choose **"Create settings preset"**
5. Save the `.gyroflow` file to the `presets/` directory in this repo

### 3. Place your LUT file

Copy your `.cube` LUT file into the `luts/` directory.

### 4. Configure settings

Edit `config.sh` to set your paths and preferences:

```bash
# These auto-detect the first file in their directories.
# Only set manually if you have multiple files and want a specific one:
GYROFLOW_PRESET="$SCRIPT_DIR/presets/specific-preset.gyroflow"
LUT_FILE="$SCRIPT_DIR/luts/specific-lut.cube"

# Optional: choose encoder
ENCODER="hevc_videotoolbox"  # or "libx265" for software encoding
```

See `config.sh` for all available options.

## Usage

Drop your GoPro `.MP4` files into `unprocessed/` and run:

```bash
./process.sh
```

Output goes to `processed/`. Originals are moved to `archive/` after successful processing.

You can also specify custom paths:

```bash
# Process a specific folder
./process.sh /path/to/footage

# Process a single file
./process.sh /path/to/GX010042.MP4

# Custom input and output directories
./process.sh /path/to/footage /path/to/output
```

## How It Works

Each file goes through a 3-stage pipeline:

1. **Gyroflow stabilization** — Uses gyro data embedded in the GoPro file to stabilize footage. Outputs a ProRes 422 intermediate (near-lossless) to preserve quality.

2. **LUT + H.265 encode** — FFmpeg applies your `.cube` LUT with tetrahedral interpolation and encodes to H.265 (HEVC). This is the only lossy encode in the pipeline.

3. **Cleanup** — Deletes the ProRes intermediate, moves the original file to an archive folder.

### Why ProRes intermediate?

Gyroflow must output an encoded video before FFmpeg can apply the LUT. By using ProRes (near-lossless) as the intermediate format, the only quality-lossy step is the final H.265 encode. This avoids the degradation of double lossy compression.

## Encoder Options

| Setting | `hevc_videotoolbox` | `libx265` |
|---|---|---|
| Speed | Fast (hardware accelerated) | Slow (CPU only) |
| Quality | Very good | Best |
| File size | Slightly larger | Slightly smaller |
| Config | `VT_QUALITY` (1-100, default: 65, higher = better) | `X265_CRF` (0-51, default: 20, lower = better) |

**Recommendation:** Start with `hevc_videotoolbox` (the default). If you need the absolute best compression ratio, switch to `libx265`.

Tune quality by processing a single file and checking the result:
- `hevc_videotoolbox`: Higher `VT_QUALITY` = larger/better, lower = smaller. Try 55-70.
- `libx265`: Lower `X265_CRF` = larger/better, higher = smaller. Try 18-22.

## GoPro Chapter Files

GoPro splits recordings longer than ~12 minutes into chapters:
- `GX010042.MP4` (chapter 1)
- `GX020042.MP4` (chapter 2)
- etc.

Each chapter is processed independently since each contains its own gyro data for stabilization. The final outputs can be concatenated afterwards if needed.

## Disk Space

ProRes 422 intermediates at 5.3K 30fps are approximately **1-2 GB per minute**. The pipeline deletes intermediates after each file by default (`DELETE_INTERMEDIATE=true` in `config.sh`), so you only need enough free space for one intermediate at a time.
