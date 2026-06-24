#!/usr/bin/env bash
# Step 00 — Download paired-end reads from NCBI SRA
#
# Uses prefetch + fasterq-dump (SRA Toolkit).
# prefetch downloads the compressed .sra file first; fasterq-dump then extracts
# reads in parallel — far faster than the legacy fastq-dump. pigz compresses
# the output in parallel using all available threads.
#
# Set SRA_ACCESSION and SAMPLE_ID in config.sh before running.
# Skip this step if you already have FASTQ files in data/raw/.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/utils.sh"

[[ -n "${SRA_ACCESSION}" ]] || die "SRA_ACCESSION is not set in config.sh"

step_start "SRA download: ${SRA_ACCESSION} → ${SAMPLE_ID}"
require_cmd prefetch
require_cmd fasterq-dump
require_cmd pigz

mkdir -p data/raw

SRA_CACHE="data/raw/${SRA_ACCESSION}"

# prefetch downloads the .sra file into a local cache directory.
# This step is resumable — safe to re-run if interrupted.
log "Prefetching ${SRA_ACCESSION}..."
prefetch "${SRA_ACCESSION}" \
    --output-directory data/raw \
    --max-size 50G

# fasterq-dump extracts reads in parallel using a multi-threaded approach.
# --split-files writes R1 and R2 into separate files (required for paired-end).
# --skip-technical drops technical reads (barcodes, linkers) not needed for alignment.
log "Extracting FASTQ (threads: ${THREADS})..."
fasterq-dump "${SRA_CACHE}" \
    --outdir data/raw \
    --split-files \
    --skip-technical \
    --threads "${THREADS}" \
    --progress

# fasterq-dump names output as <accession>_1.fastq and <accession>_2.fastq.
# Rename to the convention expected by the rest of the pipeline.
log "Renaming to match pipeline naming convention..."
mv "data/raw/${SRA_ACCESSION}_1.fastq" "data/raw/${SAMPLE_ID}_R1.fastq"
mv "data/raw/${SRA_ACCESSION}_2.fastq" "data/raw/${SAMPLE_ID}_R2.fastq"

# pigz compresses in parallel; equivalent to gzip but uses all threads.
log "Compressing with pigz (threads: ${THREADS})..."
pigz -p "${THREADS}" "data/raw/${SAMPLE_ID}_R1.fastq"
pigz -p "${THREADS}" "data/raw/${SAMPLE_ID}_R2.fastq"

# Remove the .sra cache to free disk space
log "Removing SRA cache..."
rm -rf "${SRA_CACHE}"

step_done "SRA download"
log "Output: data/raw/${SAMPLE_ID}_R1.fastq.gz"
log "        data/raw/${SAMPLE_ID}_R2.fastq.gz"
