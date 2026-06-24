#!/usr/bin/env bash
# Shared logging and validation helpers — sourced by every step script.

log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]  $*"; }
warn() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]  $*" >&2; }
die()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" >&2; exit 1; }

require_file() {
    [[ -f "$1" ]] || die "Required file not found: $1"
}

require_cmd() {
    command -v "$1" &>/dev/null || die "Command not found: $1 — are you inside 'pixi shell'?"
}

step_start() { log "=== START: $1 ==="; }
step_done()  { log "=== DONE:  $1 ==="; echo; }
