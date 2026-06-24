#!/usr/bin/env bash
# Step 06 — Convert SAM to BAM, coordinate-sort, and index
# WHY: SAM is plain text — large and slow. BAM is the binary equivalent (~5x
#      smaller). Coordinate sorting orders reads by chromosome and position,
#      which is required by all downstream GATK tools. The .bai index allows
#      tools to seek directly to any genomic region in O(1) without scanning
#      the full file. The SAM is deleted after conversion to recover disk space.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/utils.sh"

step_start "SAM → sorted BAM + index (${SAMPLE_ID})"
require_cmd samtools

IN_SAM="${DIR_ALIGN}/${SAMPLE_ID}.sam"
SORTED_BAM="${DIR_ALIGN}/${SAMPLE_ID}_sorted.bam"

require_file "${IN_SAM}"

log "Converting and sorting..."
samtools view -@ "${THREADS}" -Sb "${IN_SAM}" \
    | samtools sort -@ "${THREADS}" -o "${SORTED_BAM}"

log "Indexing sorted BAM..."
samtools index "${SORTED_BAM}"

log "Alignment statistics:"
samtools flagstat "${SORTED_BAM}"

log "Removing SAM to free disk space..."
rm "${IN_SAM}"

step_done "SAM → sorted BAM"
log "Output: ${SORTED_BAM}"
