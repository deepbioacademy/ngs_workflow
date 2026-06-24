#!/usr/bin/env bash
# Step 01 — Quality control on raw reads
# WHY: Identify adapter contamination, low-quality bases, and sequencing
#      artifacts BEFORE trimming so you have a baseline to compare against.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/utils.sh"

step_start "QC on raw reads (${SAMPLE_ID})"
require_cmd fastqc
require_file "${READ1}"
require_file "${READ2}"

mkdir -p "${DIR_QC}"

fastqc "${READ1}" "${READ2}" \
    --outdir "${DIR_QC}" \
    --threads "${THREADS}"

step_done "QC on raw reads"
log "Reports: ${DIR_QC}/${SAMPLE_ID}_R1_fastqc.html"
log "         ${DIR_QC}/${SAMPLE_ID}_R2_fastqc.html"
