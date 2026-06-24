# NGS Variant Calling Workflow

End-to-end reproducible environment for Next-Generation Sequencing (NGS) data analysis — **Variant Calling** using GATK best practices.

Uses [Pixi](https://pixi.sh/) for environment management — exact tool versions locked in `pixi.lock`, reproducible on any Linux machine without root or Docker.

## Tools Included

| Category | Tool |
|---|---|
| Quality Control | `fastqc`, `multiqc` |
| Read Trimming | `fastp` |
| Alignment | `bwa` |
| BAM Manipulation | `samtools` |
| VCF Manipulation | `bcftools` |
| Metrics & Duplicates | `picard` |
| Variant Calling | `gatk4` |

---

## Prerequisites

Install Pixi (one-time, no root needed):

```bash
curl -fsSL https://pixi.sh/install.sh | bash
```

Restart your shell or source your profile, then verify:

```bash
pixi --version
```

---

## Quickstart

### 1. Clone

```bash
git clone https://github.com/deepbioacademy/ngs_workflow.git
cd ngs_workflow
```

### 2. Install Tools

```bash
pixi install
```

Installs all bioinformatics tools from `pixi.lock` — exact reproducible versions, isolated in `.pixi/`.

### 3. Enter the Environment

```bash
pixi shell
```

All tools (`bwa`, `gatk4`, `samtools`, etc.) are now on your `$PATH`. Run any command directly.

> Alternatively, prefix individual commands with `pixi run <command>` without entering the shell.

---

## Running the Variant Calling Pipeline

All commands below assume you are inside `pixi shell` (or prefix each with `pixi run`).

### Step 1: Create Directories

```bash
mkdir -p data/raw data/reference results/qc results/trimmed results/alignment results/variants results/multiqc
```

### Step 2: Download Sample Data

Sample: HG00096 from the 1000 Genomes Project.

```bash
cd data/raw

curl -O ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/phase3/data/HG00096/sequence_read/SRR062634_1.filt.fastq.gz
curl -O ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/phase3/data/HG00096/sequence_read/SRR062634_2.filt.fastq.gz

cd ../..
```

### Step 3: Quality Control & Trimming

```bash
# FastQC on raw reads
fastqc data/raw/SRR062634_1.filt.fastq.gz data/raw/SRR062634_2.filt.fastq.gz -o results/qc/

# Trim adapters and low-quality bases
fastp \
  -i data/raw/SRR062634_1.filt.fastq.gz -I data/raw/SRR062634_2.filt.fastq.gz \
  -o results/trimmed/SRR062634_1_trimmed.fastq.gz -O results/trimmed/SRR062634_2_trimmed.fastq.gz \
  --json results/qc/fastp.json --html results/qc/fastp.html

# FastQC on trimmed reads
fastqc results/trimmed/SRR062634_1_trimmed.fastq.gz results/trimmed/SRR062634_2_trimmed.fastq.gz -o results/qc/

# Aggregate all QC reports
multiqc results/qc/ -o results/multiqc/
```

### Step 4: Download & Index Reference Genome

> Do this once per reference. hg38 is ~3 GB — indexing takes 60–90 minutes.

```bash
cd data/reference/
curl -O https://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/hg38.fa.gz
gunzip hg38.fa.gz
cd ../..

# BWA index
bwa index data/reference/hg38.fa

# GATK sequence dictionary
gatk CreateSequenceDictionary -R data/reference/hg38.fa

# samtools FASTA index
samtools faidx data/reference/hg38.fa
```

### Step 5: Alignment

```bash
bwa mem -t 4 \
  -R "@RG\tID:SRR062634\tSM:HG00096\tPL:ILLUMINA" \
  data/reference/hg38.fa \
  results/trimmed/SRR062634_1_trimmed.fastq.gz \
  results/trimmed/SRR062634_2_trimmed.fastq.gz \
  > results/alignment/SRR062634.sam
```

### Step 6: Convert, Sort & Index BAM

```bash
samtools view -Sb results/alignment/SRR062634.sam \
  | samtools sort -o results/alignment/SRR062634_sorted.bam

samtools index results/alignment/SRR062634_sorted.bam
```

### Step 7: Mark Duplicates

```bash
gatk MarkDuplicates \
  -I results/alignment/SRR062634_sorted.bam \
  -O results/alignment/SRR062634_marked_dup.bam \
  -M results/alignment/marked_dup_metrics.txt

samtools index results/alignment/SRR062634_marked_dup.bam
```

### Step 8: Variant Calling

```bash
gatk HaplotypeCaller \
  -R data/reference/hg38.fa \
  -I results/alignment/SRR062634_marked_dup.bam \
  -O results/variants/SRR062634_raw_variants.vcf
```

---

## Pixi Tasks

Frequently used steps are wired up as Pixi tasks in `pixi.toml`:

```bash
pixi run qc        # FastQC on raw reads
pixi run multiqc   # Aggregate QC reports (runs qc first)
pixi run pipeline  # Run full QC pipeline
```

---

## How It Works

`pixi.toml` declares all tool dependencies with version constraints. `pixi.lock` pins exact resolved versions. Running `pixi install` reads the lockfile and downloads pre-built conda packages from `conda-forge` and `bioconda` — no compiling, no root, no Docker.

The `.pixi/` directory holds the isolated environment. It is excluded from git via `.gitignore`.

To update tools, edit version constraints in `pixi.toml` and run `pixi update`, which regenerates `pixi.lock`.
