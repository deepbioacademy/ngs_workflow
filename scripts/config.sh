#!/usr/bin/env bash
# config.sh — Edit this file before running the pipeline.
# All paths are relative to the project root (ngs_workflow/).

SAMPLE_ID="my_sample"                        # Unique name, no spaces or slashes
SRA_ACCESSION=""                             # SRA run accession e.g. SRR062634 (leave empty if using local files)

READ1="data/raw/${SAMPLE_ID}_R1.fastq.gz"    # Forward / R1 reads
READ2="data/raw/${SAMPLE_ID}_R2.fastq.gz"    # Reverse / R2 reads

REF="data/reference/hg38.fa"                 # Must be indexed (run 04_index_reference.sh first)

# Read Group fields — required by GATK for duplicate marking and multi-sample calling
RG_ID="${SAMPLE_ID}"     # Read group ID — typically flowcell + lane
RG_SM="${SAMPLE_ID}"     # Sample name — must match BAM header
RG_PL="ILLUMINA"         # Platform: ILLUMINA | PACBIO | ONT | IONTORRENT
RG_LB="lib1"             # Library prep ID — used to detect inter-library duplicates

THREADS=4                # CPU threads (check available cores with: nproc)

# Subsetting defaults — used by 00b_subset_fastq.sh (override with --reads / --seed flags)
N_READS=50000            # Default read pairs to keep
SUBSET_SEED=42           # Default random seed

# Output directories
DIR_QC="results/qc"
DIR_TRIMMED="results/trimmed"
DIR_ALIGN="results/alignment"
DIR_VARIANTS="results/variants"
DIR_MULTIQC="results/multiqc"
