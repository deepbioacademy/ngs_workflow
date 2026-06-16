# NGS Variant Calling Workflow

End-to-end containerized environment for Next-Generation Sequencing (NGS) data analysis, specifically **Variant Calling** using GATK best practices.

Uses **Docker** + [Pixi](https://pixi.sh/) for reproducibility — same environment on every machine, no installation conflicts.

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

Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Windows/Mac) or [Docker Engine](https://docs.docker.com/engine/install/) (Linux). Verify:

```bash
docker --version
```

---

## Quickstart

### 1. Clone

```bash
git clone https://github.com/deepbioacademy/ngs_workflow.git
cd ngs_workflow
```

### 2. Build Image

```bash
docker build -t ngs-workflow .
```

> Only needed once. Rebuilds are fast — Docker caches the dependency layer and only re-runs what changed.

### 3. Run Container

```bash
# Linux / Mac
docker run -it \
  -v $(pwd)/data:/workspace/data \
  -v $(pwd)/results:/workspace/results \
  ngs-workflow

# Windows (PowerShell)
docker run -it `
  -v ${PWD}/data:/workspace/data `
  -v ${PWD}/results:/workspace/results `
  ngs-workflow

# Windows (Command Prompt)
docker run -it -v %cd%/data:/workspace/data -v %cd%/results:/workspace/results ngs-workflow
```

Your terminal prompt changes — you are now inside the container with all tools ready.

---

## Running the Variant Calling Pipeline

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

cd /workspace
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
cd /workspace

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

## Alternative: Pixi Without Docker

If you have Pixi installed locally:

```bash
# Install Pixi
curl -fsSL https://pixi.sh/install.sh | bash

# Install all tools
pixi install

# Enter the environment
pixi shell
```

Then run any pipeline command directly.

---

## For Students: How the Dockerfile Works

```dockerfile
FROM ghcr.io/prefix-dev/pixi:latest
```
Starts from the **official Pixi image** — a minimal Debian-based Linux with Pixi pre-installed. No Ubuntu bloat, no manual apt-get steps. Pulls ~200 MB instead of building from scratch.

```dockerfile
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
```
Safer shell: if any command in a pipe fails, the whole `RUN` step fails. Prevents silent errors.

```dockerfile
WORKDIR /workspace
COPY pixi.toml pixi.lock* ./
```
Creates `/workspace` and copies only the dependency files first. Docker caches this layer — if `pixi.toml` and `pixi.lock` haven't changed, the next step is skipped on rebuild.

```dockerfile
RUN pixi install --frozen
```
Installs all bioinformatics tools (`bwa`, `gatk4`, `samtools`, etc.) using exact versions from `pixi.lock`. `--frozen` means: never re-resolve dependencies, always use the lockfile — guarantees reproducibility.

```dockerfile
COPY . .
```
Copies remaining project files (scripts, etc.). Done after `pixi install` so that editing a script doesn't trigger a full tool reinstall.

```dockerfile
ENTRYPOINT ["pixi", "run"]
CMD ["bash"]
```
Every command runs inside the Pixi environment. Default: `pixi run bash` drops you into an interactive shell with all tools on `$PATH`.

### Why `.dockerignore` Matters

Without `.dockerignore`, Docker sends your entire project folder to the build daemon — including `data/` (raw FASTQ files) and `.pixi/` (local environment cache), which can exceed **6 GB**. The `.dockerignore` file excludes these, cutting build context to kilobytes and making `docker build` nearly instant.
