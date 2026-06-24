# NGS Variant Calling Workflow

End-to-end reproducible pipeline for Next-Generation Sequencing (NGS) **Variant Calling** using GATK best practices. Works with any paired-end Illumina FASTQ data.

Uses [Pixi](https://pixi.sh/) for environment management — all tool versions locked in `pixi.lock`, reproducible on any Linux machine without root or Docker.

## Tools Included

| Category | Tool |
|---|---|
| Data Download | `sra-tools`, `pigz` |
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

Pixi manages all bioinformatics tools. Install once — no root required.

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

The repository includes a pre-built directory structure (`data/`, `results/`) — no manual folder creation needed.

### 3. Install All Tools

```bash
pixi install
```

Downloads all bioinformatics tools from `conda-forge` and `bioconda` using exact versions pinned in `pixi.lock`. Isolated to `.pixi/` — nothing is installed system-wide.

### 4. Make Scripts Executable (one time)

```bash
chmod +x scripts/*.sh
```

### 5. Activate the Environment

```bash
pixi shell
```

All tools are now on your `$PATH`. All pipeline commands below run inside this shell.

---

## Running the Pipeline

### Configure Your Sample

Open `scripts/config.sh` and set your sample details:

```bash
SAMPLE_ID="my_sample"     # Unique name for this sample
SRA_ACCESSION=""          # SRA run accession e.g. SRR062634 (leave empty if using local files)
REF="data/reference/hg38.fa"
```

**Option A — Download from SRA (public data):**

Set `SRA_ACCESSION` to any SRA run accession (e.g. `SRR062634`, `ERR1234567`), then:

```bash
bash scripts/00a_download_sra.sh
```

This uses `prefetch` + `fasterq-dump` for fast parallel download, then compresses with `pigz`. Output is automatically named `data/raw/<SAMPLE_ID>_R1.fastq.gz` and `_R2.fastq.gz`.

**Option B — Use local FASTQ files:**

Place your files in `data/raw/` named `<SAMPLE_ID>_R1.fastq.gz` and `<SAMPLE_ID>_R2.fastq.gz`. Leave `SRA_ACCESSION` empty.

**Option C — Subset for training / demo (small data):**

Works with any paired-end FASTQ — not limited to this project's data.

Set source files and read count in `config.sh` (defaults already provided — update to your own files):

```bash
SRC_READ1="data/raw/your_R1.fastq.gz"   # source to subset from
SRC_READ2="data/raw/your_R2.fastq.gz"
N_READS=50000                            # read pairs to keep
```

Then run with no arguments:

```bash
./scripts/00b_subset_fastq.sh
```

Or override any value via flags without touching `config.sh`:

```bash
./scripts/00b_subset_fastq.sh \
  --in1 /path/to/any_R1.fastq.gz \
  --in2 /path/to/any_R2.fastq.gz \
  --out1 data/subset/demo_R1.fastq.gz \
  --out2 data/subset/demo_R2.fastq.gz \
  --reads 10000
```

Takes first N read pairs using `fastp --reads_to_process` — no filtering applied. 50,000 reads run the full pipeline in seconds on a laptop.

### Run the Full Pipeline

```bash
# using bash
bash scripts/run_pipeline.sh

# or directly (requires chmod +x from Setup step 4)
./scripts/run_pipeline.sh
```

### Run a Single Step

```bash
bash scripts/run_pipeline.sh --step 05   # runs only 05_align.sh
./scripts/run_pipeline.sh --step 05      # equivalent
```

### Run Steps Individually

```bash
./scripts/00a_download_sra.sh      # optional — download from SRA
./scripts/00b_subset_fastq.sh      # optional — subset for training/demo
./scripts/01_qc_raw.sh
./scripts/02_trim.sh
./scripts/03_qc_trimmed.sh
./scripts/04_index_reference.sh    # one-time reference setup
./scripts/05_align.sh
./scripts/06_sort_bam.sh
./scripts/07_mark_duplicates.sh
./scripts/08_variant_calling.sh
```

> **Note:** `00a_download_sra.sh`, `00b_subset_fastq.sh`, and `04_index_reference.sh` are excluded from `run_pipeline.sh`. Reference indexing takes 60–90 minutes and is a one-time setup. Run these manually before the first pipeline run.

---

## Pipeline Steps — Biological Context

### Step 00a: Download from SRA (`00a_download_sra.sh`)

**Why:** The NCBI Sequence Read Archive (SRA) is the world's largest repository of raw sequencing data — thousands of publicly available human and non-human datasets. Accessing public data lets you reproduce published studies, benchmark your pipeline, or practice on real data without generating it yourself.

`prefetch` downloads the compressed `.sra` file to a local cache — this step is resumable if interrupted. `fasterq-dump` then extracts reads in parallel threads (far faster than the legacy `fastq-dump`). `pigz` compresses the output using all available CPU cores, reducing storage to ~30% of the uncompressed size.

**Input:** `SRA_ACCESSION` set in `config.sh` (any SRR/ERR/DRR accession)
**Output:** `data/raw/<SAMPLE_ID>_R1.fastq.gz`, `data/raw/<SAMPLE_ID>_R2.fastq.gz`

---

### Step 00b: Subset FASTQ (`00b_subset_fastq.sh`) — training/demo only

**Why:** Full WGS datasets are 10–50 GB — impractical for live demos or classroom sessions. Subsetting to 50,000–100,000 read pairs reduces runtime to seconds while preserving realistic QC metrics, trimming behaviour, and alignment output.

`fastp --reads_to_process` takes the first N read pairs with all filtering disabled — no quality trimming, no adapter removal, no length filtering. Pairs stay in sync automatically since both files are processed together.

**Flags:** `--in1`, `--in2`, `--out1`, `--out2`, `--reads` — all optional, all default to `config.sh` values
**Output:** `data/subset/<SAMPLE_ID>_subset_demo_R1.fastq.gz`, `_R2.fastq.gz`

---

### Step 01: QC on Raw Reads (`01_qc_raw.sh`)

**Why:** Sequencers produce errors — low-quality bases at read ends, adapter contamination (synthetic sequences that must not align to the genome), and GC bias. FastQC generates a per-sample HTML report revealing these issues *before* trimming, giving you a baseline to compare against later.

**Output:** `results/qc/<sample>_R1_fastqc.html`, `_R2_fastqc.html`
Key metrics: per-base quality, adapter content, GC distribution, duplication levels.

---

### Step 02: Adapter Trimming (`02_trim.sh`)

**Why:** Illumina adapters bind DNA fragments to the flow cell. When a fragment is shorter than the read length, the sequencer reads into the adapter — producing non-biological sequence that fails alignment. Fastp removes adapters, trims low-quality bases (Phred < 20, i.e., >1% error probability), and drops reads shorter than 36 bp that would multi-map unreliably.

**Output:** `results/trimmed/<sample>_R1_trimmed.fastq.gz`, `_R2_trimmed.fastq.gz`, `results/qc/<sample>_fastp.html`
Expect 95–99% of reads to pass. High failure rate signals poor sequencing quality.

---

### Step 03: QC on Trimmed Reads (`03_qc_trimmed.sh`)

**Why:** Verify that trimming resolved the problems found in Step 01. FastQC is re-run on trimmed reads; MultiQC aggregates all reports (raw + trimmed + fastp) into a single dashboard — critical when processing multiple samples.

**Output:** Updated FastQC reports + `results/multiqc/multiqc_report.html`
Adapter content and low-quality base warnings should now pass.

---

### Step 04: Index Reference Genome (`04_index_reference.sh`)

**Why:** Three indices are required by three different tools:
- **BWA index** (`.bwt`, `.sa`, etc.): suffix array enabling alignment of millions of reads in minutes instead of days
- **GATK sequence dictionary** (`.dict`): contig name and length table for validating VCF headers
- **samtools FASTA index** (`.fai`): byte-offset map enabling O(1) random access to any genomic region

hg38 is the current gold-standard human reference assembly (GRCh38). Run this step **once per machine**.

**Output:** Index files alongside the reference FASTA in `data/reference/`

---

### Step 05: Alignment (`05_align.sh`)

**Why:** To call variants we must know where in the 3-billion-base genome each read originates. BWA-MEM uses a seed-and-extend strategy: seeds short exact matches via the Burrows-Wheeler index, then extends alignments with a Smith-Waterman model. The **Read Group** (`@RG`) tag embeds sample identity into every read — required by GATK for multi-sample workflows and correct duplicate detection.

**Output:** `results/alignment/<sample>.sam`
Expect >95% overall alignment rate for good-quality human WGS.

---

### Step 06: Convert, Sort & Index BAM (`06_sort_bam.sh`)

**Why:** SAM (Sequence Alignment Map) is plain text — large and slow to parse. BAM is the binary-compressed equivalent (~5× smaller). Coordinate sorting orders reads by chromosome and position, which downstream GATK tools require. The `.bai` index allows random region access without scanning the entire file. The SAM is deleted after conversion to recover disk space.

**Output:** `results/alignment/<sample>_sorted.bam` + `.bai`
`samtools flagstat` is printed — check mapped read percentage.

---

### Step 07: Mark Duplicates (`07_mark_duplicates.sh`)

**Why:** PCR amplification during library preparation creates identical copies of the same DNA molecule. Without marking, every duplicate inflates variant allele frequencies, generating false positives. GATK MarkDuplicates identifies read pairs with identical 5′ mapping coordinates (the PCR duplicate hallmark) and sets the 0x400 SAM flag. HaplotypeCaller automatically ignores flagged reads. Reads are **marked, not removed**.

**Output:** `results/alignment/<sample>_markdup.bam` + duplication metrics file
Typical WGS duplication rate: 5–20%. Above 40% signals low library complexity.

---

### Step 08: Variant Calling (`08_variant_calling.sh`)

**Why:** HaplotypeCaller identifies positions where this sample's genome differs from the reference — these are **variants** (SNPs and small indels). Unlike simple pileup callers, it locally reassembles reads into haplotypes using a De Bruijn graph around each candidate site, then scores haplotype likelihoods with a pair-HMM model. Local reassembly makes it significantly more accurate near indels and in repetitive regions.

**Output:** `results/variants/<sample>_raw_variants.vcf`
Raw VCF contains candidate variants plus false positives. Apply VQSR or hard filters before biological interpretation.

> For multi-sample cohorts: use `-ERC GVCF` mode in this step, then run `GenomicsDBImport` + `GenotypeGVCFs` for joint genotyping.

---

## Project Structure

```
ngs_workflow/
├── pixi.toml                    # Tool dependencies + task definitions
├── pixi.lock                    # Exact locked versions (always commit this)
├── scripts/
│   ├── config.sh                # ← Edit this for your sample
│   ├── utils.sh                 # Shared logging helpers
│   ├── 00a_download_sra.sh      # Download from NCBI SRA (optional)
│   ├── 00b_subset_fastq.sh      # Subset reads for training/demo (optional)
│   ├── 01_qc_raw.sh
│   ├── 02_trim.sh
│   ├── 03_qc_trimmed.sh
│   ├── 04_index_reference.sh    # One-time reference setup
│   ├── 05_align.sh
│   ├── 06_sort_bam.sh
│   ├── 07_mark_duplicates.sh
│   ├── 08_variant_calling.sh
│   └── run_pipeline.sh          # Master runner (steps 01–03, 05–08)
├── data/
│   ├── raw/                     # Full FASTQ input files
│   ├── subset/                  # Subsetted reads for training/demo
│   └── reference/               # Reference genome + indices
└── results/
    ├── qc/                      # FastQC + fastp reports
    ├── trimmed/                 # Adapter-trimmed reads
    ├── alignment/               # SAM/BAM files
    ├── variants/                # VCF output
    └── multiqc/                 # Aggregated QC dashboard
```

---

## Pixi Tasks (Quick QC)

```bash
pixi run qc        # FastQC on data/raw/*.fastq.gz → results/qc/
pixi run multiqc   # Aggregate QC reports (runs qc first)
pixi run qc-pipeline  # Full QC pipeline (FastQC + MultiQC only)
```

---

## How Pixi Works

`pixi.toml` declares tool dependencies with version constraints. `pixi.lock` pins exact resolved versions. `pixi install` downloads pre-built conda packages from `conda-forge` and `bioconda` — no compiling, no root access. The `.pixi/` environment directory is git-ignored. To update tools, edit constraints in `pixi.toml` and run `pixi update`.
