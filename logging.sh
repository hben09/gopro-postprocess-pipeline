#!/usr/bin/env bash
# logging.sh — Shared logging utilities for the GoPro post-processing pipeline

# --- TTY-aware color definitions ---

if [[ -t 1 ]]; then
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    RESET=$'\033[0m'
    RED=$'\033[31m'
    GREEN=$'\033[32m'
    YELLOW=$'\033[33m'
    BLUE=$'\033[34m'
    CYAN=$'\033[36m'
else
    BOLD="" DIM="" RESET="" RED="" GREEN="" YELLOW="" BLUE="" CYAN=""
fi

# --- Log functions ---

log()       { echo "${DIM}[$(date '+%H:%M:%S')]${RESET} $*"; }
log_info()  { echo "${DIM}[$(date '+%H:%M:%S')]${RESET} ${CYAN}$*${RESET}"; }
log_ok()    { echo "${DIM}[$(date '+%H:%M:%S')]${RESET} ${GREEN}$*${RESET}"; }
log_warn()  { echo "${DIM}[$(date '+%H:%M:%S')]${RESET} ${YELLOW}WARNING:${RESET} $*" >&2; }
log_error() { echo "${DIM}[$(date '+%H:%M:%S')]${RESET} ${RED}ERROR:${RESET} $*" >&2; }

# --- Timer helpers ---

timer_start() { date +%s; }

timer_elapsed() {
    local start="$1"
    local now
    now="$(date +%s)"
    local secs=$((now - start))
    printf '%dm%02ds' $((secs / 60)) $((secs % 60))
}

# --- Section helpers ---

print_header() {
    echo "${BOLD}${BLUE}━━━ $1 ━━━${RESET}"
}

print_rule() {
    echo "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}
