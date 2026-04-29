# NGS Variant Calling Workflow

This repository provides an end-to-end containerized environment for Next-Generation Sequencing (NGS) data analysis, specifically focusing on **Variant Calling** using the GATK (Genome Analysis Toolkit) best practices.

By utilizing **Docker** for containerization (and [Pixi](https://pixi.sh/) under the hood), this project guarantees reproducibility, ease of deployment, and a hassle-free setup of bioinformatics tools.

## 🛠️ Included Tools

The container is pre-configured with the standard variant calling stack:
- **Quality Control**: `fastqc`, `multiqc`
- **Read Trimming & Filtering**: `fastp`
- **Alignment**: `bwa`
- **BAM Manipulation**: `samtools`
- **VCF Manipulation**: `bcftools`
- **Metrics & Duplicates**: `picard`
- **Variant Calling**: `gatk4`

---

## 🚀 Step-by-Step Guide for Beginners

Follow these steps to clone the repository, set up your environment, and run a complete Variant Calling pipeline.

### Step 1: Get the Code (Clone the Repository)
First, you need to download this project to your computer. Open your terminal (or Command Prompt/PowerShell on Windows) and run:

```bash
git clone https://github.com/deepbioacademy/ngs_workflow.git
cd ngs_workflow
```

### Step 2: Understand and Install Docker

![Docker Architecture](img/docker.png)

Bioinformatics tools often have complex dependencies. Installing them directly on your computer can cause conflicts and errors. 

**Docker** solves this by creating a "Container"—a lightweight, standalone, and completely isolated mini-computer running inside your actual computer. 
- **What it does:** It packages all our necessary tools into a single blueprint called an **Image** (defined by the `Dockerfile`). 
- **Why it's great:** When you start a **Container** from this Image, you get an environment that works exactly the same way on every machine. No installation headaches!

**Installation:**
Before you begin, install Docker Desktop on your machine:
- **Windows / Mac:** Download and install [Docker Desktop](https://www.docker.com/products/docker-desktop/).
- **Linux:** Follow the instructions for [Docker Engine](https://docs.docker.com/engine/install/).

Once installed, open Docker Desktop and make sure it is running. Verify it in your terminal: `docker --version`.

### Step 3: Setup (Build the Docker Image)
Think of this step as downloading and installing all the bioinformatics tools into your isolated mini-computer. You only need to do this once.

Make sure you are inside the `ngs_workflow` folder, then run:
```bash
docker build -t ngs-workflow .
```
**What does this command mean?**
- `docker build`: Create a new image.
- `-t ngs-workflow`: Name (tag) our image "ngs-workflow".
- `.`: Look in the *current* folder for the setup instructions.

### Step 4: Execution (Run the Container)
Now we start the Container and "mount" (connect) our local folders so the tools inside can read our raw data and save results to our actual computer.

Run the following command:
```bash
docker run -it \
  -v $(pwd)/data:/workspace/data \
  -v $(pwd)/results:/workspace/results \
  ngs-workflow
```
*(Windows Users: Replace `$(pwd)` with `%cd%` in Command Prompt, or `${PWD}` in PowerShell).*

**You are now inside the Docker container!** Your terminal prompt will change, and every tool is ready to be used.

---

## 🧬 Step 5: Run the Variant Calling Pipeline

Now that you are inside the container, let's run a complete analysis. We will use sample data from the 1000 Genomes Project.

### 5.1 Prepare Directories and Download Data
Before running the tools, we need to create the required output folders and download our sample data.
```bash
# Create all necessary folders
mkdir -p data/raw data/reference results/qc results/trimmed results/alignment results/variants

# Download sample data
wget -P data/raw ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/phase3/data/HG00096/sequence_read/SRR062634_1.filt.fastq.gz
wget -P data/raw ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/phase3/data/HG00096/sequence_read/SRR062634_2.filt.fastq.gz
```

### 5.2 Quality Control & Trimming
Evaluate the quality of your raw reads and trim adapters.
```bash
# Run FastQC
fastqc data/raw/SRR062634_1.filt.fastq.gz data/raw/SRR062634_2.filt.fastq.gz -o results/qc/

# Trim reads with fastp
fastp -i data/raw/SRR062634_1.filt.fastq.gz -I data/raw/SRR062634_2.filt.fastq.gz \
      -o results/trimmed/SRR062634_1_trimmed.fastq.gz -O results/trimmed/SRR062634_2_trimmed.fastq.gz
```

### 5.3 Reference Genome Indexing
Before alignment, index your reference genome (only needs to be done once per reference).
*(Make sure you have a reference genome `ref.fa` in `data/reference/` before running this)*.
```bash
# Index with BWA
bwa index data/reference/ref.fa

# Create sequence dictionary for GATK
gatk CreateSequenceDictionary -R data/reference/ref.fa

# Create samtools index
samtools faidx data/reference/ref.fa
```

### 5.4 Alignment
Align the trimmed reads to the reference genome.
```bash
bwa mem -t 4 -R "@RG\tID:SRR062634\tSM:HG00096\tPL:ILLUMINA" \
    data/reference/ref.fa \
    results/trimmed/SRR062634_1_trimmed.fastq.gz \
    results/trimmed/SRR062634_2_trimmed.fastq.gz > results/alignment/SRR062634.sam
```

### 5.5 BAM Conversion & Sorting
Convert SAM to BAM and sort it.
```bash
samtools view -Sb results/alignment/SRR062634.sam | samtools sort -o results/alignment/SRR062634_sorted.bam
samtools index results/alignment/SRR062634_sorted.bam
```

### 5.6 Mark Duplicates (GATK / Picard)
Mark PCR duplicates so they don't skew variant calling.
```bash
gatk MarkDuplicates \
    -I results/alignment/SRR062634_sorted.bam \
    -O results/alignment/SRR062634_marked_dup.bam \
    -M results/alignment/marked_dup_metrics.txt

samtools index results/alignment/SRR062634_marked_dup.bam
```

### 5.7 Variant Calling (HaplotypeCaller)
Finally, call variants using GATK HaplotypeCaller.
```bash
gatk HaplotypeCaller \
    -R data/reference/ref.fa \
    -I results/alignment/SRR062634_marked_dup.bam \
    -O results/variants/SRR062634_raw_variants.vcf
```

---

## 📦 Alternative: Managing Dependencies with Pixi (No Docker)

If you prefer not to use Docker, you can install the tools directly on your system using [Pixi](https://pixi.sh/):

1. Install Pixi: `curl -fsSL https://pixi.sh/install.sh | bash`
2. Install tools: `pixi install` (Run this inside the `ngs_workflow` folder)
3. Enter the environment: `pixi shell`

All dependencies are defined in `pixi.toml`.
