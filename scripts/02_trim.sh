#!/usr/bin/env bash
# Step 02 — Adapter trimming and quality filtering
# WHY: Remove Illumina adapter sequences and low-quality bases (Phred < 20)
#      that will fail to align or introduce false variants. Also filters reads
#      that become too short after trimming (<36 bp) as they will multi-map.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/utils.sh"

step_start "Adapter trimming (${SAMPLE_ID})"
require_cmd fastp
require_file "${READ1}"
require_file "${READ2}"

mkdir -p "${DIR_TRIMMED}" "${DIR_QC}"

TRIM_R1="${DIR_TRIMMED}/${SAMPLE_ID}_R1_trimmed.fastq.gz"
TRIM_R2="${DIR_TRIMMED}/${SAMPLE_ID}_R2_trimmed.fastq.gz"

fastp \
    --in1  "${READ1}" \
    --in2  "${READ2}" \
    --out1 "${TRIM_R1}" \
    --out2 "${TRIM_R2}" \
    --json "${DIR_QC}/${SAMPLE_ID}_fastp.json" \
    --html "${DIR_QC}/${SAMPLE_ID}_fastp.html" \
    --thread "${THREADS}" \
    --detect_adapter_for_pe \
    --qualified_quality_phred 20 \
    --length_required 36 \
    --correction

step_done "Adapter trimming"
log "Trimmed reads: ${TRIM_R1}"
log "               ${TRIM_R2}"
log "Trimming report: ${DIR_QC}/${SAMPLE_ID}_fastp.html"
