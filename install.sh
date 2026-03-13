#!/usr/bin/env bash
set -euo pipefail

# install.sh — Check and install dependencies for the GoPro post-processing pipeline

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

pass=0
fail=0
warn=0

check_pass() { echo "  ✓ $1"; ((pass++)) || true; }
check_fail() { echo "  ✗ $1"; ((fail++)) || true; }
check_warn() { echo "  ⚠ $1"; ((warn++)) || true; }

echo "Checking dependencies..."
echo

# --- Homebrew ---
echo "Homebrew:"
if command -v brew &>/dev/null; then
    check_pass "Homebrew found at $(command -v brew)"
else
    check_fail "Homebrew not found"
    echo "    Install from: https://brew.sh"
    echo
    echo "Cannot continue without Homebrew."
    exit 1
fi
echo

# --- FFmpeg ---
echo "FFmpeg:"
if command -v ffmpeg &>/dev/null; then
    check_pass "FFmpeg found at $(command -v ffmpeg)"
else
    echo "  FFmpeg not found — installing via Homebrew..."
    brew install ffmpeg
    if command -v ffmpeg &>/dev/null; then
        check_pass "FFmpeg installed successfully"
    else
        check_fail "FFmpeg installation failed"
    fi
fi
echo

# --- HEVC VideoToolbox encoder ---
echo "HEVC hardware encoder:"
if ffmpeg -encoders 2>/dev/null | grep -q hevc_videotoolbox; then
    check_pass "hevc_videotoolbox available"
else
    check_warn "hevc_videotoolbox not available (set ENCODER=\"libx265\" in config.sh as fallback)"
fi
echo

# --- Gyroflow ---
echo "Gyroflow:"
if [[ -x "$GYROFLOW_BIN" ]]; then
    check_pass "Gyroflow found at $GYROFLOW_BIN"
else
    check_fail "Gyroflow not found at $GYROFLOW_BIN"
    echo "    Download from: https://gyroflow.xyz/download"
    echo "    Install to /Applications/ and ensure the path in config.sh is correct."
fi
echo

# --- Summary ---
echo "---"
echo "Results: $pass passed, $fail failed, $warn warnings"
if [[ $fail -gt 0 ]]; then
    echo "Fix the issues above before running the pipeline."
    exit 1
else
    echo "Ready to process footage."
fi
