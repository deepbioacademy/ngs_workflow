#!/usr/bin/env bash
# Step 00b — Subset paired-end FASTQ files (training / demo / quick testing)
#
# USAGE:
#   bash scripts/00b_subset_fastq.sh --in1 R1.fastq.gz --in2 R2.fastq.gz \
#                                    --out1 sub_R1.fastq.gz --out2 sub_R2.fastq.gz \
#                                    [--reads 50000]
#
# --in1 / --in2    Source FASTQ files (required; gzip or uncompressed)
# --out1 / --out2  Output paths (default: data/subset/<derived-from-in1>_subset_demo_R1/R2.fastq.gz)
# --reads          Read pairs to keep (default: N_READS from config.sh)
#
# Uses fastp --reads_to_process — takes the first N read pairs, no filtering applied.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/utils.sh"

require_cmd fastp

# Defaults from config.sh
IN1="${SRC_READ1}"
IN2="${SRC_READ2}"
OUT1="data/subset/__derived__"
OUT2="data/subset/__derived__"
READS="${N_READS}"

# Parse flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        --in1)   IN1="$2";   shift 2 ;;
        --in2)   IN2="$2";   shift 2 ;;
        --out1)  OUT1="$2";  shift 2 ;;
        --out2)  OUT2="$2";  shift 2 ;;
        --reads) READS="$2"; shift 2 ;;
        *) die "Unknown argument: $1. See header of this script for usage." ;;
    esac
done

[[ -n "${IN1}" ]] || die "SRC_READ1 not set in config.sh and --in1 not provided"
[[ -n "${IN2}" ]] || die "SRC_READ2 not set in config.sh and --in2 not provided"

require_file "${IN1}"
require_file "${IN2}"

# Derive base name from IN1: strip extensions and _1/_R1 suffixes
BASE=$(basename "${IN1}" | sed 's/\.\(fastq\|fq\)\.gz$//' | sed 's/\.\(fastq\|fq\)$//' | sed 's/_[R]*[12][._].*//' | sed 's/_[R]*[12]$//')

# Use derived base for default output if --out1/--out2 not explicitly set
[[ "${OUT1}" == "data/subset/__derived__" ]] && OUT1="data/subset/${BASE}_subset_demo_R1.fastq.gz"
[[ "${OUT2}" == "data/subset/__derived__" ]] && OUT2="data/subset/${BASE}_subset_demo_R2.fastq.gz"

step_start "Subset FASTQ — ${READS} read pairs"
log "R1: ${IN1} → ${OUT1}"
log "R2: ${IN2} → ${OUT2}"

mkdir -p "$(dirname "${OUT1}")" "$(dirname "${OUT2}")"

fastp \
    --in1  "${IN1}" \
    --in2  "${IN2}" \
    --out1 "${OUT1}" \
    --out2 "${OUT2}" \
    --reads_to_process "${READS}" \
    --disable_adapter_trimming \
    --disable_quality_filtering \
    --disable_length_filtering \
    --thread "${THREADS}" \
    --json /dev/null \
    --html /dev/null

ACTUAL=$(zcat "${OUT1}" | awk 'NR%4==1' | wc -l)
log "Read pairs written: ${ACTUAL}"

step_done "Subset FASTQ"
log "Output: ${OUT1}"
log "        ${OUT2}"
