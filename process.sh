#!/usr/bin/env bash
set -euo pipefail

# process.sh — GoPro post-processing pipeline
# Usage: ./process.sh /path/to/footage [/path/to/output]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/logging.sh"

# --- Counters and state ---

SUCCESS_COUNT=0
FAIL_COUNT=0
FAILED_FILES=()
CURRENT_INTERMEDIATE=""
CURRENT_OUTPUT=""
FILE_INDEX=0
TOTAL_FILES=0
PIPELINE_START=""

# --- Display functions ---

print_banner() {
    echo
    print_header "GoPro Post-Processing Pipeline"
    echo "  ${DIM}Files:${RESET}   $TOTAL_FILES (.MP4)"
    echo "  ${DIM}Output:${RESET}  $OUTPUT_DIR"
    echo "  ${DIM}Encoder:${RESET} $ENCODER"
    if [[ "${APPLY_LUT:-true}" == "true" ]]; then
        echo "  ${DIM}LUT:${RESET}     $(basename "${LUT_FILE:-none}")"
    else
        echo "  ${DIM}LUT:${RESET}     disabled"
    fi
    echo "  ${DIM}Preset:${RESET}  $(basename "${GYROFLOW_PRESET:-none}")"
    print_rule
    echo
}

print_summary() {
    local total=$((SUCCESS_COUNT + FAIL_COUNT))
    local elapsed
    elapsed="$(timer_elapsed "$PIPELINE_START")"

    echo
    print_header "Summary"
    echo "  Processed: $total"
    echo "  ${GREEN}✓ Succeeded: $SUCCESS_COUNT${RESET}"
    if [[ $FAIL_COUNT -gt 0 ]]; then
        echo "  ${RED}✗ Failed:    $FAIL_COUNT${RESET}"
        for f in "${FAILED_FILES[@]}"; do
            echo "    ${RED}- $f${RESET}"
        done
    fi
    echo "  ${DIM}Total time:  $elapsed${RESET}"
    print_rule
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

    if [[ "${APPLY_LUT:-true}" == "true" ]]; then
        if [[ -z "${LUT_FILE:-}" ]]; then
            log_error "No .cube LUT found. Place a LUT file in luts/"
            ((errors++))
        elif [[ ! -f "$LUT_FILE" ]]; then
            log_error "LUT file not found: $LUT_FILE"
            ((errors++))
        fi
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
        log "${YELLOW}⊘ Skipping${RESET} $filename — already processed"
        return 0
    fi

    local file_start
    file_start="$(timer_start)"

    log "${BOLD}[${FILE_INDEX}/${TOTAL_FILES}] ${filename}${RESET}"

    # --- Stage 1: Gyroflow stabilization ---
    local stage_start
    stage_start="$(timer_start)"
    log "  ├─ Stabilize (gyroflow)..."
    CURRENT_INTERMEDIATE="$gyroflow_output"

    if ! "$GYROFLOW_BIN" "$input_file" \
        --preset "$GYROFLOW_PRESET" \
        -p "{ 'codec': 'ProRes', 'codec_options': '3', 'bitrate': 0, 'use_gpu': true, 'audio': true }" \
        -t "_stabilized" \
        -f; then
        log_error "  ├─ Stabilize ${RED}✗${RESET} — Gyroflow failed for $filename"
        CURRENT_INTERMEDIATE=""
        return 1
    fi

    if [[ ! -f "$gyroflow_output" ]]; then
        log_error "  ├─ Stabilize ${RED}✗${RESET} — output not found: $gyroflow_output"
        CURRENT_INTERMEDIATE=""
        return 1
    fi

    log "  ├─ Stabilize ${GREEN}✓${RESET} ${DIM}($(timer_elapsed "$stage_start"))${RESET}"

    # Move intermediate to output directory
    mv "$gyroflow_output" "$intermediate"
    CURRENT_INTERMEDIATE="$intermediate"

    # --- Stage 2: LUT + H.265 encode ---
    stage_start="$(timer_start)"
    log "  ├─ Encode H.265..."
    CURRENT_OUTPUT="$output_file"

    local -a encoder_args
    if [[ "$ENCODER" == "hevc_videotoolbox" ]]; then
        encoder_args=(-c:v hevc_videotoolbox -q:v "$VT_QUALITY" -pix_fmt p010le -profile:v main10)
    else
        encoder_args=(-c:v libx265 -crf "$X265_CRF" -pix_fmt yuv420p10le -profile:v main10)
    fi

    local vf=""
    if [[ "${APPLY_LUT:-true}" == "true" ]]; then
        vf="format=yuv422p16le,lut3d='${LUT_FILE}':interp=tetrahedral"
    fi
    if [[ "$OUTPUT_RESOLUTION" != "source" ]]; then
        local scale="scale=${OUTPUT_RESOLUTION/x/:}:flags=lanczos"
        vf="${vf:+${vf},}${scale}"
    fi

    local -a vf_args=()
    if [[ -n "$vf" ]]; then
        vf_args=(-vf "$vf")
    fi

    if ! ffmpeg -nostdin -i "$intermediate" \
        "${vf_args[@]}" \
        "${encoder_args[@]}" \
        -colorspace bt709 -color_trc bt709 -color_primaries bt709 \
        -tag:v hvc1 -c:a copy \
        -movflags +faststart -y "$output_file"; then
        log_error "  ├─ Encode ${RED}✗${RESET} — FFmpeg failed for $filename"
        CURRENT_OUTPUT=""
        return 1
    fi

    log "  ├─ Encode ${GREEN}✓${RESET} ${DIM}($(timer_elapsed "$stage_start"))${RESET}"

    # --- Stage 3: Cleanup ---
    log "  └─ Cleanup..."

    if [[ ! -s "$output_file" ]]; then
        log_error "  └─ Cleanup ${RED}✗${RESET} — output file is missing or empty"
        CURRENT_OUTPUT=""
        return 1
    fi

    if [[ "$DELETE_INTERMEDIATE" == "true" ]]; then
        rm -f "$intermediate"
    fi

    mv "$input_file" "$ARCHIVE_DIR/" 2>/dev/null || { cp "$input_file" "$ARCHIVE_DIR/" && rm -f "$input_file"; }

    CURRENT_INTERMEDIATE=""
    CURRENT_OUTPUT=""

    log "  └─ ${GREEN}Done${RESET} ${DIM}$(timer_elapsed "$file_start")${RESET} → ${DIM}$output_file${RESET}"
    return 0
}

# --- Trap handler ---

cleanup_on_exit() {
    echo
    log_warn "Interrupted — cleaning up partial files..."
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
    shopt -s nocaseglob
    for f in "$INPUT_DIR"/*.mp4; do
        [[ -f "$f" ]] && INPUT_FILES+=("$f")
    done
    shopt -u nocaseglob
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

TOTAL_FILES=${#INPUT_FILES[@]}
PIPELINE_START="$(timer_start)"

print_banner

for f in "${INPUT_FILES[@]}"; do
    ((FILE_INDEX++))
    if process_file "$f"; then
        ((SUCCESS_COUNT++))
    else
        ((FAIL_COUNT++))
        FAILED_FILES+=("$(basename "$f")")
        log_error "Failed: ${BOLD}$(basename "$f")${RESET} — skipping to next file"
    fi
    echo
done

print_summary

if [[ $FAIL_COUNT -gt 0 ]]; then
    exit 1
fi
