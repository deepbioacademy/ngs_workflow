#!/usr/bin/env bash
# Step 03 — QC on trimmed reads + MultiQC aggregation
# WHY: Verify trimming resolved the issues found in Step 01. MultiQC merges all
#      FastQC and fastp reports into one dashboard — essential for comparing
#      pre- vs post-trim quality and for batch sample review.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/utils.sh"

step_start "QC on trimmed reads + MultiQC (${SAMPLE_ID})"
require_cmd fastqc
require_cmd multiqc

TRIM_R1="${DIR_TRIMMED}/${SAMPLE_ID}_R1_trimmed.fastq.gz"
TRIM_R2="${DIR_TRIMMED}/${SAMPLE_ID}_R2_trimmed.fastq.gz"

require_file "${TRIM_R1}"
require_file "${TRIM_R2}"

mkdir -p "${DIR_QC}" "${DIR_MULTIQC}"

fastqc "${TRIM_R1}" "${TRIM_R2}" \
    --outdir "${DIR_QC}" \
    --threads "${THREADS}"

multiqc "${DIR_QC}" \
    --outdir "${DIR_MULTIQC}" \
    --force

step_done "QC on trimmed reads + MultiQC"
log "MultiQC report: ${DIR_MULTIQC}/multiqc_report.html"
