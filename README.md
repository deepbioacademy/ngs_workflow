# NGS Variant Calling Workflow

End-to-end reproducible pipeline for Next-Generation Sequencing (NGS) **Variant Calling** using GATK best practices.

Uses [Pixi](https://pixi.sh/) for environment management — all tool versions locked in `pixi.lock`, reproducible on any Linux machine without root or Docker.

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

## Setup

### 1. Install Pixi

Pixi manages all bioinformatics tools. Install it once — no root required.

```bash
curl -fsSL https://pixi.sh/install.sh | bash
```

Restart your shell (or run `source ~/.bashrc`), then verify:

```bash
pixi --version
```

### 2. Clone the Repository

```bash
git clone https://github.com/deepbioacademy/ngs_workflow.git
cd ngs_workflow
```

The repository includes a pre-built directory structure under `data/` and `results/` — no need to create folders manually.

### 3. Install All Tools

```bash
pixi install
```

Downloads all bioinformatics tools from `conda-forge` and `bioconda` using exact versions pinned in `pixi.lock`. Tools are isolated in `.pixi/` — nothing is installed system-wide.

### 4. Activate the Environment

```bash
pixi shell
```

All tools (`bwa`, `gatk4`, `samtools`, `fastqc`, etc.) are now on your `$PATH`. Every command in this guide runs inside this shell.

> To run a single command without entering the shell: `pixi run <command>`

---

## Variant Calling Pipeline

### Step 1: Download Sample Data

**Why:** We need raw sequencing reads (FASTQ format) as input. FASTQ files store each read as four lines: a header, the nucleotide sequence, a separator, and Phred quality scores per base.

**Sample:** HG00096 — a human male from the 1000 Genomes Project (British ancestry). Paired-end Illumina reads, chromosome 20 region.

```bash
cd data/raw

curl -O ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/phase3/data/HG00096/sequence_read/SRR062634_1.filt.fastq.gz
curl -O ftp://ftp-trace.ncbi.nih.gov/1000genomes/ftp/phase3/data/HG00096/sequence_read/SRR062634_2.filt.fastq.gz

cd ../..
```

**Expected output:** Two gzipped FASTQ files — `SRR062634_1.filt.fastq.gz` (forward reads) and `SRR062634_2.filt.fastq.gz` (reverse reads). Each file contains millions of 100 bp reads.

---

### Step 2: Quality Control

**Why:** Sequencers are not perfect. Raw reads can contain adapter contamination (synthetic sequences that must never align to the genome), low-quality bases at read ends (Phred score < 20, i.e., > 1% error rate), and GC bias. FastQC generates a per-sample HTML report so you can detect these issues before they corrupt downstream results. MultiQC aggregates all FastQC reports into a single dashboard — essential when processing many samples.

```bash
# Assess raw read quality
fastqc data/raw/SRR062634_1.filt.fastq.gz data/raw/SRR062634_2.filt.fastq.gz -o results/qc/

# Aggregate QC reports
multiqc results/qc/ -o results/multiqc/
```

**Expected output:**
- `results/qc/SRR062634_1.filt_fastqc.html` — interactive QC report per file
- `results/multiqc/multiqc_report.html` — combined dashboard

Key metrics to check: per-base quality scores, adapter content, sequence duplication levels, GC distribution.

---

### Step 3: Adapter Trimming

**Why:** Illumina sequencing uses adapter sequences to bind DNA fragments to the flow cell. When a fragment is shorter than the read length, the sequencer reads into the adapter — producing non-biological sequence that will fail to align. Fastp removes adapters, trims low-quality bases, and filters out reads that are too short to align reliably. This step directly improves alignment rate and variant calling accuracy.

```bash
fastp \
  -i data/raw/SRR062634_1.filt.fastq.gz \
  -I data/raw/SRR062634_2.filt.fastq.gz \
  -o results/trimmed/SRR062634_1_trimmed.fastq.gz \
  -O results/trimmed/SRR062634_2_trimmed.fastq.gz \
  --json results/qc/fastp.json \
  --html results/qc/fastp.html \
  --thread 4
```

**Expected output:**
- `results/trimmed/SRR062634_1_trimmed.fastq.gz` / `*_2_trimmed.fastq.gz` — cleaned reads
- `results/qc/fastp.html` — trimming summary (reads passed/failed, adapter stats)

Expect 95–99% reads to pass. A high failure rate signals low sequencing quality.

---

### Step 4: Post-Trim QC

**Why:** Verify that trimming actually solved the problems identified in Step 2. Compare pre- and post-trim reports to confirm adapter contamination is gone and quality scores improved.

```bash
fastqc results/trimmed/SRR062634_1_trimmed.fastq.gz \
        results/trimmed/SRR062634_2_trimmed.fastq.gz \
        -o results/qc/

multiqc results/qc/ -o results/multiqc/ --force
```

**Expected output:** Updated `multiqc_report.html` showing both raw and trimmed metrics side by side. Adapter content modules should now pass.

---

### Step 5: Download & Index Reference Genome

**Why:** Alignment requires a reference genome — a curated consensus sequence representing a "standard" human genome. We use **hg38** (GRCh38), the current gold-standard assembly. Indexing pre-computes lookup structures (suffix arrays, hash tables) so BWA can locate a read's position in ~3 billion bases in milliseconds rather than scanning the entire genome. Three indices are needed: BWA's own index for alignment, a sequence dictionary for GATK's contig ordering checks, and a FASTA index for samtools random access.

> **Note:** hg38 is ~3 GB. Indexing takes 60–90 minutes. Do this once per machine.

```bash
cd data/reference/
curl -O https://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/hg38.fa.gz
gunzip hg38.fa.gz
cd ../..

# BWA index — enables read alignment
bwa index data/reference/hg38.fa

# GATK sequence dictionary — needed for variant calling
gatk CreateSequenceDictionary -R data/reference/hg38.fa

# samtools FASTA index — enables random region access
samtools faidx data/reference/hg38.fa
```

**Expected output:**
- `data/reference/hg38.fa` — uncompressed reference
- `hg38.fa.amb`, `.ann`, `.bwt`, `.pac`, `.sa` — BWA index files
- `hg38.dict` — sequence dictionary
- `hg38.fa.fai` — FASTA index

---

### Step 6: Alignment

**Why:** We need to determine where each sequenced read originates in the genome before we can identify variants. BWA-MEM (Burrows-Wheeler Aligner, MEM algorithm) is the standard for Illumina paired-end data — it handles reads up to 1 Mbp, is tolerant of sequencing errors, and correctly maps reads spanning splice junctions or structural variants. The **Read Group** (`-R` flag) tags every read with sample identity, platform, and library — mandatory for multi-sample GATK workflows and for distinguishing PCR duplicates.

```bash
bwa mem -t 4 \
  -R "@RG\tID:SRR062634\tSM:HG00096\tPL:ILLUMINA\tLB:lib1\tPU:unit1" \
  data/reference/hg38.fa \
  results/trimmed/SRR062634_1_trimmed.fastq.gz \
  results/trimmed/SRR062634_2_trimmed.fastq.gz \
  > results/alignment/SRR062634.sam
```

**Expected output:** `results/alignment/SRR062634.sam` — SAM format file with one alignment record per read. Expect >95% overall alignment rate for a good-quality human sample. The SAM file can be several GB uncompressed.

---

### Step 7: Convert, Sort & Index BAM

**Why:** SAM (Sequence Alignment Map) is a plain-text format — large and slow to query. BAM is the binary-compressed equivalent (~5× smaller). Sorting by genomic coordinate is required because GATK and most downstream tools assume reads are ordered by position, not by the order they were sequenced. Indexing creates a `.bai` file that allows tools to jump directly to any genomic region without scanning the entire BAM.

```bash
# Convert SAM → BAM and coordinate-sort in one pipe
samtools view -Sb results/alignment/SRR062634.sam \
  | samtools sort -o results/alignment/SRR062634_sorted.bam

# Index the sorted BAM
samtools index results/alignment/SRR062634_sorted.bam

# Optional: remove the large SAM file to save disk space
rm results/alignment/SRR062634.sam
```

**Expected output:**
- `results/alignment/SRR062634_sorted.bam` — coordinate-sorted binary alignment
- `results/alignment/SRR062634_sorted.bam.bai` — BAM index

---

### Step 8: Mark Duplicates

**Why:** PCR amplification is required during library preparation, but it creates identical copies of the same DNA molecule. If not marked, these duplicates are counted as independent evidence for a variant — artificially inflating variant allele frequencies and causing false positives. Picard's `MarkDuplicates` identifies read pairs with identical 5' mapping positions (the hallmark of PCR duplicates) and flags them with a SAM flag. GATK automatically ignores flagged duplicates during variant calling. This step does **not** remove reads — it only marks them.

```bash
gatk MarkDuplicates \
  -I results/alignment/SRR062634_sorted.bam \
  -O results/alignment/SRR062634_marked_dup.bam \
  -M results/alignment/marked_dup_metrics.txt

samtools index results/alignment/SRR062634_marked_dup.bam
```

**Expected output:**
- `results/alignment/SRR062634_marked_dup.bam` — BAM with duplicates flagged
- `results/alignment/marked_dup_metrics.txt` — duplication rate report

Check the metrics file: typical WGS duplication rates are 5–20%. Rates >40% suggest library complexity problems.

---

### Step 9: Variant Calling

**Why:** HaplotypeCaller is GATK's core variant caller. It identifies positions where the sample's sequence differs from the reference genome — these are candidate **variants** (SNPs and small indels). The algorithm locally reassembles reads into haplotypes around candidate variant sites using a De Bruijn graph, then evaluates the probability of each haplotype given the observed data using a hidden Markov model. This local reassembly makes it far more accurate than simple pileup-based callers, especially in repetitive regions and around indels.

```bash
gatk HaplotypeCaller \
  -R data/reference/hg38.fa \
  -I results/alignment/SRR062634_marked_dup.bam \
  -O results/variants/SRR062634_raw_variants.vcf \
  --native-pair-hmm-threads 4
```

**Expected output:** `results/variants/SRR062634_raw_variants.vcf` — VCF (Variant Call Format) file listing all candidate SNPs and indels with position, reference allele, alternate allele, genotype, and quality scores. Raw output contains both true variants and false positives — further filtering (VQSR or hard filters) is applied in production pipelines.

---

## Pixi Tasks

Frequently used QC steps are wired as Pixi tasks:

```bash
pixi run qc        # FastQC on raw reads → results/qc/
pixi run multiqc   # Aggregate QC reports (runs qc first)
pixi run pipeline  # Run full QC pipeline
```

---

## Project Structure

```
ngs_workflow/
├── pixi.toml              # Tool dependencies and task definitions
├── pixi.lock              # Exact locked versions (commit this file)
├── data/
│   ├── raw/               # Input FASTQ files
│   └── reference/         # Reference genome + indices
└── results/
    ├── qc/                # FastQC + fastp reports
    ├── trimmed/           # Adapter-trimmed reads
    ├── alignment/         # SAM/BAM files
    ├── variants/          # VCF output
    └── multiqc/           # Aggregated QC dashboard
```

`data/` and `results/` directories are pre-created in this repo (via `.gitkeep` files) — no manual `mkdir` needed.

---

## How Pixi Works

`pixi.toml` declares all tool dependencies with version constraints. `pixi.lock` pins exact resolved versions. `pixi install` reads the lockfile and downloads pre-built conda packages from `conda-forge` and `bioconda` — no compiling, no root access required.

The `.pixi/` directory holds the isolated environment and is excluded from git. To update tools, edit version constraints in `pixi.toml` and run `pixi update` to regenerate `pixi.lock`.
