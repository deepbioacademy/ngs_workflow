#!/usr/bin/env bash
# Step 07 — Mark PCR duplicates
# WHY: PCR amplification during library prep creates identical copies of the same
#      DNA molecule. Without marking, every duplicate counts as independent
#      evidence for a variant, inflating allele frequencies and causing false
#      positives. GATK MarkDuplicates identifies read pairs sharing identical
#      5-prime mapping coordinates (the PCR duplicate signature) and sets the
#      0x400 SAM flag. HaplotypeCaller automatically skips flagged reads.
#      Reads are MARKED, not removed — they can still be used for other analyses.
#      Duplication rate: 5-20% is typical for WGS; >40% signals low library complexity.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/utils.sh"

step_start "Mark duplicates (${SAMPLE_ID})"
require_cmd gatk
require_cmd samtools

SORTED_BAM="${DIR_ALIGN}/${SAMPLE_ID}_sorted.bam"
MARKDUP_BAM="${DIR_ALIGN}/${SAMPLE_ID}_markdup.bam"
METRICS="${DIR_ALIGN}/${SAMPLE_ID}_markdup_metrics.txt"

require_file "${SORTED_BAM}"

log "Running GATK MarkDuplicates..."
gatk MarkDuplicates \
    --INPUT  "${SORTED_BAM}" \
    --OUTPUT "${MARKDUP_BAM}" \
    --METRICS_FILE "${METRICS}"

log "Indexing..."
samtools index "${MARKDUP_BAM}"

log "Duplication metrics:"
grep -A 2 "LIBRARY" "${METRICS}" || true

step_done "Mark duplicates"
log "Output BAM:  ${MARKDUP_BAM}"
log "Metrics:     ${METRICS}"
