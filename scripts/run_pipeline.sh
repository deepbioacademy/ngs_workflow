#!/usr/bin/env bash
# run_pipeline.sh — Run the full NGS variant calling pipeline
#
# USAGE:
#   1. Edit scripts/config.sh with your sample name, read paths, and reference.
#   2. Run: bash scripts/run_pipeline.sh
#   3. To run a single step: bash scripts/run_pipeline.sh --step 05
#
# PREREQUISITES: Run inside 'pixi shell'. Index reference first (step 04) if needed.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

STEPS=(
    "01_qc_raw.sh"
    "02_trim.sh"
    "03_qc_trimmed.sh"
    "05_align.sh"
    "06_sort_bam.sh"
    "07_mark_duplicates.sh"
    "08_variant_calling.sh"
)

# Parse --step flag to run a single step
ONLY_STEP=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --step) ONLY_STEP="$2"; shift 2 ;;
        *) die "Unknown argument: $1. Usage: $0 [--step <NN>]" ;;
    esac
done

log "NGS Variant Calling Pipeline"
log "Working directory: $(pwd)"
echo

if [[ -n "${ONLY_STEP}" ]]; then
    MATCH=$(printf '%s\n' "${STEPS[@]}" | grep "^${ONLY_STEP}" || true)
    [[ -n "${MATCH}" ]] || die "No step found matching: ${ONLY_STEP}"
    bash "${SCRIPT_DIR}/${MATCH}"
else
    for STEP in "${STEPS[@]}"; do
        bash "${SCRIPT_DIR}/${STEP}"
    done
    log "Pipeline complete. Results in results/"
fi
