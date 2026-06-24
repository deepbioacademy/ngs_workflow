#!/usr/bin/env bash
# config.sh — Edit this file before running the pipeline.
# All paths are relative to the project root (ngs_workflow/).

SAMPLE_ID="SRR062634"                        # Unique name, no spaces or slashes
SRA_ACCESSION=""                             # SRA run accession e.g. SRR062634 (leave empty if using local files)

READ1="data/raw/${SAMPLE_ID}_1.filt.fastq.gz"    # Forward / R1 reads
READ2="data/raw/${SAMPLE_ID}_2.filt.fastq.gz"    # Reverse / R2 reads

REF="data/reference/hg38.fa"                 # Must be indexed (run 04_index_reference.sh first)

# Read Group fields — required by GATK for duplicate marking and multi-sample calling
RG_ID="${SAMPLE_ID}"     # Read group ID — typically flowcell + lane
RG_SM="${SAMPLE_ID}"     # Sample name — must match BAM header
RG_PL="ILLUMINA"         # Platform: ILLUMINA | PACBIO | ONT | IONTORRENT
RG_LB="lib1"             # Library prep ID — used to detect inter-library duplicates

THREADS=4                # CPU threads (check available cores with: nproc)

# Subsetting — used by 00b_subset_fastq.sh (all overridable via CLI flags)
SRC_READ1="data/raw/SRR062634_1.filt.fastq.gz"   # Source R1 to subset from
SRC_READ2="data/raw/SRR062634_2.filt.fastq.gz"   # Source R2 to subset from
N_READS=50000            # Read pairs to keep

# Output directories
DIR_QC="results/qc"
DIR_TRIMMED="results/trimmed"
DIR_ALIGN="results/alignment"
DIR_VARIANTS="results/variants"
DIR_MULTIQC="results/multiqc"
