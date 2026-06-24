#!/usr/bin/env bash
# Step 05 — Align trimmed reads to reference genome
# WHY: Determines the genomic origin of each read. BWA-MEM uses a seed-and-extend
#      strategy: seeds short exact matches via the BWT index, then extends them
#      with Smith-Waterman. The Read Group tag (@RG) embeds sample metadata into
#      every read — GATK mandates this for duplicate marking and multi-sample
#      genotyping. Expect >95% alignment rate for good-quality human WGS data.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/utils.sh"

step_start "Read alignment — BWA-MEM (${SAMPLE_ID})"
require_cmd bwa
require_file "${REF}"
require_file "${REF}.bwt"

TRIM_R1="${DIR_TRIMMED}/${SAMPLE_ID}_R1_trimmed.fastq.gz"
TRIM_R2="${DIR_TRIMMED}/${SAMPLE_ID}_R2_trimmed.fastq.gz"
require_file "${TRIM_R1}"
require_file "${TRIM_R2}"

mkdir -p "${DIR_ALIGN}"

OUT_SAM="${DIR_ALIGN}/${SAMPLE_ID}.sam"
RG_TAG="@RG\tID:${RG_ID}\tSM:${RG_SM}\tPL:${RG_PL}\tLB:${RG_LB}\tPU:unit1"

log "Aligning with BWA-MEM (threads: ${THREADS})..."
bwa mem \
    -t "${THREADS}" \
    -R "${RG_TAG}" \
    "${REF}" \
    "${TRIM_R1}" \
    "${TRIM_R2}" \
    > "${OUT_SAM}"

step_done "Read alignment"
log "Output SAM: ${OUT_SAM}"
log "Check alignment stats in next step after BAM conversion."
