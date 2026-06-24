#!/usr/bin/env bash
# Step 08 — Variant calling with GATK HaplotypeCaller
# WHY: HaplotypeCaller identifies positions where this sample differs from the
#      reference genome (SNPs and small indels). Unlike simple pileup callers,
#      it locally reassembles reads into haplotypes using a De Bruijn graph
#      around every candidate variant site, then scores each haplotype with a
#      pair-HMM model against the observed reads. This local reassembly is
#      critical for accuracy near indels and in repetitive regions.
#
#      Output: raw VCF with all candidate variants. This includes true variants
#      AND false positives — apply VQSR or hard filters in a production pipeline.
#
#      For multi-sample cohorts: use -ERC GVCF mode here, then run
#      GenomicsDBImport + GenotypeGVCFs for joint genotyping.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/utils.sh"

step_start "Variant calling — HaplotypeCaller (${SAMPLE_ID})"
require_cmd gatk
require_file "${REF}"
require_file "${REF}.fai"
require_file "${REF%.fa}.dict"

MARKDUP_BAM="${DIR_ALIGN}/${SAMPLE_ID}_markdup.bam"
OUT_VCF="${DIR_VARIANTS}/${SAMPLE_ID}_raw_variants.vcf"

require_file "${MARKDUP_BAM}"
require_file "${MARKDUP_BAM}.bai"

mkdir -p "${DIR_VARIANTS}"

log "Running HaplotypeCaller..."
gatk HaplotypeCaller \
    --reference             "${REF}" \
    --input                 "${MARKDUP_BAM}" \
    --output                "${OUT_VCF}" \
    --native-pair-hmm-threads "${THREADS}"

log "Variant summary:"
grep -v "^#" "${OUT_VCF}" | wc -l | xargs echo "  Total raw variants:"

step_done "Variant calling"
log "Raw VCF: ${OUT_VCF}"
log "Next: apply variant filtration (VQSR or hard filters) before downstream analysis."
