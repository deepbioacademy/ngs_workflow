#!/usr/bin/env bash
# Step 04 — Download and index reference genome
# Three indices are required by three tools:
#   BWA index (.bwt etc.): suffix array for read alignment
#   GATK dict (.dict):     contig ordering for VCF header validation
#   samtools fai (.fai):   byte-offset map for O(1) random region access
#
# Run ONCE per reference genome. hg38 indexing takes 60-90 min, ~8 GB disk.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/utils.sh"

step_start "Reference genome indexing ($(basename ${REF}))"
require_cmd bwa
require_cmd gatk
require_cmd samtools

mkdir -p "$(dirname "${REF}")"

# Download only if reference is missing
if [[ ! -f "${REF}" ]]; then
    GZ="${REF}.gz"
    log "Reference not found. Downloading hg38..."
    curl -L -o "${GZ}" "https://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/hg38.fa.gz"
    log "Decompressing..."
    gunzip "${GZ}"
else
    log "Reference already exists, skipping download: ${REF}"
fi

# BWA index
if [[ ! -f "${REF}.bwt" ]]; then
    log "Building BWA index..."
    bwa index "${REF}"
else
    log "BWA index already exists, skipping."
fi

# GATK sequence dictionary
DICT="${REF%.fa}.dict"
if [[ ! -f "${DICT}" ]]; then
    log "Building GATK sequence dictionary..."
    gatk CreateSequenceDictionary -R "${REF}"
else
    log "Sequence dictionary already exists, skipping."
fi

# samtools FASTA index
if [[ ! -f "${REF}.fai" ]]; then
    log "Building samtools FASTA index..."
    samtools faidx "${REF}"
else
    log "FASTA index already exists, skipping."
fi

step_done "Reference genome indexing"
