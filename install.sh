#!/usr/bin/env bash
set -euo pipefail

# install.sh — Check and install dependencies for the GoPro post-processing pipeline

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/logging.sh"

pass=0
fail=0
warn=0

check_pass() { echo "  ${GREEN}✓${RESET} $1"; ((pass++)) || true; }
check_fail() { echo "  ${RED}✗${RESET} $1"; ((fail++)) || true; }
check_warn() { echo "  ${YELLOW}⚠${RESET} $1"; ((warn++)) || true; }

echo
print_header "Dependency Check"
echo

# --- Package Manager ---
echo "${BOLD}Package Manager:${RESET}"
if command -v dnf &>/dev/null; then
    check_pass "dnf found (Fedora)"
else
    check_warn "dnf not found — manual dependency installation may be needed"
fi
echo

# --- FFmpeg ---
echo "${BOLD}FFmpeg:${RESET}"
if command -v ffmpeg &>/dev/null; then
    check_pass "FFmpeg found at $(command -v ffmpeg)"
else
    echo "  FFmpeg not found — installing via dnf..."
    sudo dnf install -y ffmpeg
    if command -v ffmpeg &>/dev/null; then
        check_pass "FFmpeg installed successfully"
    else
        check_fail "FFmpeg installation failed"
    fi
fi
echo

# --- AV1 encoders ---
echo "${BOLD}AV1 encoders:${RESET}"
ENCODER_LIST="$(ffmpeg -encoders 2>/dev/null || true)"
if echo "$ENCODER_LIST" | grep -q av1_vaapi; then
    check_pass "av1_vaapi (AMD hardware) available"
else
    check_warn "av1_vaapi not available (hardware encoding unavailable)"
fi
if echo "$ENCODER_LIST" | grep -q libsvtav1; then
    check_pass "libsvtav1 (SVT-AV1 software) available"
else
    check_warn "libsvtav1 not available (software fallback unavailable)"
fi
echo

# --- VAAPI ---
echo "${BOLD}VAAPI:${RESET}"
if [[ -e "${VAAPI_DEVICE:-/dev/dri/renderD128}" ]]; then
    check_pass "VAAPI device found at ${VAAPI_DEVICE:-/dev/dri/renderD128}"
    if command -v vainfo &>/dev/null; then
        if vainfo 2>/dev/null | grep -q "VAProfileAV1Profile0.*VAEntrypointEncSlice"; then
            check_pass "VAAPI AV1 encode supported"
        else
            check_warn "VAAPI AV1 encode not detected (av1_vaapi may not work)"
        fi
    else
        check_warn "vainfo not found — install libva-utils to verify VAAPI support"
    fi
else
    check_warn "VAAPI device not found at ${VAAPI_DEVICE:-/dev/dri/renderD128}"
fi
echo

# --- Gyroflow ---
echo "${BOLD}Gyroflow:${RESET}"
if [[ -n "${GYROFLOW_BIN:-}" && -x "$GYROFLOW_BIN" ]]; then
    check_pass "Gyroflow found at $GYROFLOW_BIN"
elif command -v gyroflow &>/dev/null; then
    check_pass "Gyroflow found at $(command -v gyroflow)"
else
    check_fail "Gyroflow not found on PATH"
    echo "    Download AppImage from: https://gyroflow.xyz/download"
    echo "    Make sure 'gyroflow' is available on PATH."
fi
echo

# --- Summary ---
print_rule
echo "Results: ${GREEN}$pass passed${RESET}, ${RED}$fail failed${RESET}, ${YELLOW}$warn warnings${RESET}"
if [[ $fail -gt 0 ]]; then
    echo "Fix the issues above before running the pipeline."
    exit 1
else
    echo "${GREEN}Ready to process footage.${RESET}"
fi
