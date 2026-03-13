# config.sh — User-tunable settings for the GoPro post-processing pipeline
# This file is sourced by process.sh. Edit values below to match your setup.

# Resolve the directory this config file lives in
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Gyroflow ---

# Path to Gyroflow binary
GYROFLOW_BIN="/Applications/Gyroflow.app/Contents/MacOS/Gyroflow"

# Path to .gyroflow preset (auto-detects first .gyroflow file in presets/)
GYROFLOW_PRESET="$(ls "$SCRIPT_DIR"/presets/*.gyroflow 2>/dev/null | head -n1)"

# --- Color grading ---

# Path to .cube LUT file (auto-detects first .cube file in luts/)
LUT_FILE="$(ls "$SCRIPT_DIR"/luts/*.cube 2>/dev/null | head -n1)"

# --- Encoding ---

# H.265 encoder: "hevc_videotoolbox" (hardware, fast) or "libx265" (software, best compression)
ENCODER="hevc_videotoolbox"

# Quality for hevc_videotoolbox (1-100, lower = larger/better). Try 55-70.
VT_QUALITY=65

# CRF for libx265 (0-51, lower = larger/better). Try 18-22.
X265_CRF=20

# --- Cleanup ---

# Subdirectory name for archived originals (created inside the input directory)
ARCHIVE_DIR_NAME="originals"

# Delete ProRes intermediate files after successful encode
DELETE_INTERMEDIATE=true
