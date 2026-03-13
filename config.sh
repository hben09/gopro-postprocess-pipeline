# config.sh — User-tunable settings for the GoPro post-processing pipeline
# This file is sourced by process.sh. Edit values below to match your setup.

# Resolve the directory this config file lives in
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Gyroflow ---

# Path to Gyroflow binary (auto-detects on PATH; override with full path if needed)
GYROFLOW_BIN="$HOME/Applications/Gyroflow/gyroflow"

# Path to .gyroflow preset (auto-detects first .gyroflow file in presets/)
GYROFLOW_PRESET="$(ls "$SCRIPT_DIR"/presets/*.gyroflow 2>/dev/null | head -n1 || true)"

# --- Color grading ---

# Apply LUT color grading (true/false). Set to false to skip LUT.
APPLY_LUT=false

# Path to .cube LUT file (auto-detects first .cube file in luts/)
LUT_FILE="$(ls "$SCRIPT_DIR"/luts/*.cube 2>/dev/null | head -n1 || true)"

# --- Encoding ---

# AV1 encoder: "av1_vaapi" (AMD hardware, fastest) or "libsvtav1" (software, best quality)
ENCODER="av1_vaapi"

# VAAPI render device for hardware encoding
VAAPI_DEVICE="/dev/dri/renderD128"

# Quality for av1_vaapi QVBR mode (1-255, lower = larger/better). Try 25-35.
VAAPI_QUALITY=30

# Max bitrate for av1_vaapi QVBR mode. Sets upper bound for variable bitrate.
# For 4K 30fps GoPro footage, 50M provides good headroom.
VAAPI_BITRATE="50M"

# CRF for libsvtav1 (0-63, lower = larger/better). Try 25-32.
SVT_CRF=28

# Preset for libsvtav1 (0-13, lower = slower/better quality). 4-6 recommended.
SVT_PRESET=5

# Output resolution: "WIDTHxHEIGHT" or "source" to keep original
OUTPUT_RESOLUTION="3840x2160"

# --- Directories ---

# Default directories (relative to this script's location)
UNPROCESSED_DIR="$SCRIPT_DIR/1_unprocessed"
PROCESSED_DIR="$SCRIPT_DIR/2_processed"
ARCHIVE_DIR="$SCRIPT_DIR/3_archive"

# --- Cleanup ---

# Delete ProRes intermediate files after successful encode
DELETE_INTERMEDIATE=true
