# config.sh — User-tunable settings for the GoPro post-processing pipeline
# This file is sourced by process.sh. Edit values below to match your setup.

# Resolve the directory this config file lives in
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Gyroflow ---

# Path to Gyroflow binary
GYROFLOW_BIN="/Applications/Gyroflow.app/Contents/MacOS/Gyroflow"

# Path to .gyroflow preset (auto-selects if one, prompts if multiple)
_gyroflow_presets=()
while IFS= read -r f; do
    _gyroflow_presets+=("$f")
done < <(ls "$SCRIPT_DIR"/presets/*.gyroflow 2>/dev/null || true)

if [[ ${#_gyroflow_presets[@]} -eq 1 ]]; then
    GYROFLOW_PRESET="${_gyroflow_presets[0]}"
elif [[ ${#_gyroflow_presets[@]} -gt 1 ]]; then
    echo "Available Gyroflow presets:"
    for i in "${!_gyroflow_presets[@]}"; do
        echo "  $((i+1))) $(basename "${_gyroflow_presets[$i]}")"
    done
    while true; do
        read -rp "Select preset [1-${#_gyroflow_presets[@]}]: " _choice
        if [[ "$_choice" =~ ^[0-9]+$ ]] && (( _choice >= 1 && _choice <= ${#_gyroflow_presets[@]} )); then
            GYROFLOW_PRESET="${_gyroflow_presets[$((_choice-1))]}"
            break
        fi
        echo "Invalid selection. Try again."
    done
else
    GYROFLOW_PRESET=""
fi
unset _gyroflow_presets _choice

# --- Color grading ---

# Apply LUT color grading (true/false). Set to false to skip LUT.
APPLY_LUT=true

# Path to .cube LUT file (auto-detects first .cube file in luts/)
LUT_FILE="$(ls "$SCRIPT_DIR"/luts/*.cube 2>/dev/null | head -n1 || true)"

# --- Encoding ---

# H.265 encoder: "hevc_videotoolbox" (hardware, fast) or "libx265" (software, best compression)
ENCODER="hevc_videotoolbox"

# Quality for hevc_videotoolbox (1-100, higher = larger/better). Try 55-70.
VT_QUALITY=55

# CRF for libx265 (0-51, lower = larger/better). Try 20-24 for 10-bit.
X265_CRF=22

# Preset for libx265 ("medium", "slow", "slower"). Slower = better compression.
X265_PRESET="slow"

# Advanced x265 tuning params (optimized for GoPro outdoor/action footage)
X265_PARAMS="aq-mode=3:psy-rd=2.0:psy-rdoq=1.0:rc-lookahead=60:bframes=8"

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
