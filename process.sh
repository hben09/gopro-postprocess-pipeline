#!/usr/bin/env bash
set -euo pipefail

# process.sh — GoPro post-processing pipeline
# Usage: ./process.sh /path/to/footage [/path/to/output]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# --- Counters and state ---

SUCCESS_COUNT=0
FAIL_COUNT=0
FAILED_FILES=()
CURRENT_INTERMEDIATE=""
CURRENT_OUTPUT=""

# --- Utility functions ---

log()       { echo "[$(date '+%H:%M:%S')] $*"; }
log_error() { echo "[$(date '+%H:%M:%S')] ERROR: $*" >&2; }

print_summary() {
    echo
    echo "=== Summary ==="
    echo "  Processed: $((SUCCESS_COUNT + FAIL_COUNT))"
    echo "  Succeeded: $SUCCESS_COUNT"
    echo "  Failed:    $FAIL_COUNT"
    if [[ $FAIL_COUNT -gt 0 ]]; then
        echo "  Failed files:"
        for f in "${FAILED_FILES[@]}"; do
            echo "    - $f"
        done
    fi
}

usage() {
    echo "Usage: $0 [/path/to/footage] [/path/to/output]"
    echo
    echo "  footage   A single .MP4 file or a directory containing .MP4 files"
    echo "            (default: unprocessed/)"
    echo "  output    Output directory (default: processed/)"
    exit 1
}

# --- Validation ---

validate_config() {
    local errors=0

    if [[ -z "${GYROFLOW_PRESET:-}" ]]; then
        log_error "No .gyroflow preset found. Place a preset file in presets/"
        ((errors++))
    elif [[ ! -f "$GYROFLOW_PRESET" ]]; then
        log_error "Gyroflow preset not found: $GYROFLOW_PRESET"
        ((errors++))
    fi

    if [[ -z "${LUT_FILE:-}" ]]; then
        log_error "No .cube LUT found. Place a LUT file in luts/"
        ((errors++))
    elif [[ ! -f "$LUT_FILE" ]]; then
        log_error "LUT file not found: $LUT_FILE"
        ((errors++))
    fi

    if [[ ! -x "$GYROFLOW_BIN" ]]; then
        log_error "Gyroflow not found at: $GYROFLOW_BIN"
        log_error "Run ./install.sh to check dependencies."
        ((errors++))
    fi

    if [[ "$ENCODER" != "hevc_videotoolbox" && "$ENCODER" != "libx265" ]]; then
        log_error "Invalid encoder: $ENCODER (must be hevc_videotoolbox or libx265)"
        ((errors++))
    fi

    if ! command -v ffmpeg &>/dev/null; then
        log_error "ffmpeg not found on PATH. Run ./install.sh to install."
        ((errors++))
    fi

    if [[ $errors -gt 0 ]]; then
        exit 1
    fi
}

# --- Per-file pipeline ---

process_file() {
    local input_file="$1"
    local filename basename input_dir
    filename="$(basename "$input_file")"
    basename="${filename%.*}"
    input_dir="$(cd "$(dirname "$input_file")" && pwd)"

    local gyroflow_output="${input_dir}/${basename}_stabilized.mov"
    local intermediate="${OUTPUT_DIR}/${basename}_stabilized.mov"
    local output_file="${OUTPUT_DIR}/${basename}.mp4"

    # Skip if already processed
    if [[ -s "$output_file" ]]; then
        log "Skipping $filename — already processed"
        return 0
    fi

    log "Processing $filename..."

    # --- Stage 1: Gyroflow stabilization ---
    log "  Stage 1/3: Stabilizing..."
    CURRENT_INTERMEDIATE="$gyroflow_output"

    if ! "$GYROFLOW_BIN" "$input_file" \
        --preset "$GYROFLOW_PRESET" \
        -p "{ 'codec': 'ProRes', 'bitrate': 0, 'use_gpu': true, 'audio': true }" \
        -t "_stabilized" \
        -f; then
        log_error "Gyroflow failed for $filename"
        CURRENT_INTERMEDIATE=""
        return 1
    fi

    if [[ ! -f "$gyroflow_output" ]]; then
        log_error "Gyroflow output not found: $gyroflow_output"
        CURRENT_INTERMEDIATE=""
        return 1
    fi

    # Move intermediate to output directory
    mv "$gyroflow_output" "$intermediate"
    CURRENT_INTERMEDIATE="$intermediate"

    # --- Stage 2: LUT + H.265 encode ---
    log "  Stage 2/3: Encoding H.265..."
    CURRENT_OUTPUT="$output_file"

    local encoder_flags
    if [[ "$ENCODER" == "hevc_videotoolbox" ]]; then
        encoder_flags="-c:v hevc_videotoolbox -q:v $VT_QUALITY"
    else
        encoder_flags="-c:v libx265 -crf $X265_CRF"
    fi

    if ! ffmpeg -i "$intermediate" \
        -vf "lut3d='${LUT_FILE}':interp=tetrahedral" \
        $encoder_flags \
        -tag:v hvc1 -c:a aac -b:a 256k \
        -movflags +faststart -y "$output_file"; then
        log_error "FFmpeg encoding failed for $filename"
        CURRENT_OUTPUT=""
        return 1
    fi

    # --- Stage 3: Cleanup ---
    log "  Stage 3/3: Cleanup..."

    if [[ ! -s "$output_file" ]]; then
        log_error "Output file is missing or empty: $output_file"
        CURRENT_OUTPUT=""
        return 1
    fi

    if [[ "$DELETE_INTERMEDIATE" == "true" ]]; then
        rm -f "$intermediate"
    fi

    mv "$input_file" "$ARCHIVE_DIR/"

    CURRENT_INTERMEDIATE=""
    CURRENT_OUTPUT=""
    log "  Done: $output_file"
    return 0
}

# --- Trap handler ---

cleanup_on_exit() {
    echo
    log "Interrupted — cleaning up partial files..."
    [[ -n "$CURRENT_INTERMEDIATE" && -f "$CURRENT_INTERMEDIATE" ]] && rm -f "$CURRENT_INTERMEDIATE"
    [[ -n "$CURRENT_OUTPUT" && -f "$CURRENT_OUTPUT" ]] && rm -f "$CURRENT_OUTPUT"
    print_summary
    exit 130
}

# --- Argument parsing ---

INPUT_PATH="${1:-$UNPROCESSED_DIR}"
INPUT_FILES=()

if [[ -f "$INPUT_PATH" ]]; then
    INPUT_FILES=("$(cd "$(dirname "$INPUT_PATH")" && pwd)/$(basename "$INPUT_PATH")")
    INPUT_DIR="$(cd "$(dirname "$INPUT_PATH")" && pwd)"
elif [[ -d "$INPUT_PATH" ]]; then
    INPUT_DIR="$(cd "$INPUT_PATH" && pwd)"
    for f in "$INPUT_DIR"/*.MP4 "$INPUT_DIR"/*.mp4; do
        [[ -f "$f" ]] && INPUT_FILES+=("$f")
    done
    if [[ ${#INPUT_FILES[@]} -eq 0 ]]; then
        log_error "No .MP4 files found in $INPUT_DIR"
        exit 1
    fi
else
    log_error "Input path not found: $INPUT_PATH"
    exit 1
fi

OUTPUT_DIR="${2:-$PROCESSED_DIR}"
mkdir -p "$OUTPUT_DIR" "$ARCHIVE_DIR"

# --- Run ---

validate_config

trap cleanup_on_exit INT TERM

log "Processing ${#INPUT_FILES[@]} file(s)..."
log "Output:  $OUTPUT_DIR"
log "Encoder: $ENCODER"
echo

for f in "${INPUT_FILES[@]}"; do
    if process_file "$f"; then
        ((SUCCESS_COUNT++))
    else
        ((FAIL_COUNT++))
        FAILED_FILES+=("$(basename "$f")")
        log_error "Failed: $(basename "$f") — skipping to next file"
    fi
    echo
done

print_summary

if [[ $FAIL_COUNT -gt 0 ]]; then
    exit 1
fi
