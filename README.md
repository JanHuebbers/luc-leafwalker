# luc-leafwalker
The repo provides a pipeline for formatting, normalizing, and analyzing data retrieved from luciferase complementation imaging (LCI) assays. It includes reproducible input generation, reference-based normalization, and downstream visualization/statistical evaluation.

## Overview
`luc-leafwalker` provides a workflow to prepare input tables, normalize luciferase complementation data, and generate downstream analyses and visualizations in a reproducible way. The pipeline is designed for experiments with multiple conditions, experiments, and replicates, and supports reference-based normalization within replicates.

## Environment setup
Create the Conda environment from the provided file:
```bash
conda env create -f environment.yml
conda activate luc-leafwalker
```
Install Ubuntu/WSL system libraries required for some R package installations:
```bash
sudo apt update
sudo apt install -y \
  cmake \
  libudunits2-dev \
  libcairo2-dev \
  libexpat1-dev \
  pkg-config
```
Install required R packages:
```bash
Rscript src/install_r_packages.R
```
Create project directories
```bash
mkdir -p Output config Data
```

## Workflow
The analysis consists of three main steps:

### 1. Create input `.xlsx` files
Raw experiment layouts are generated as structured Excel files containing sample combinations, experiment structure, and replicate setup.
Use `luc_empty_input_generator.py` to generate empty `.xlsx` templates for luciferase complementation experiments.
Example:
```bash
bash src/run_empty_input_MLO1vsEXO70.sh
```
This example script shows how to define:
- output file
- number of experiments
- number of replicates
- NLuc constructs
- CLuc constructs
- normalizer
- optional layout settings such as --no-spacers
You can adapt the example shell script for additional experiment sets.

### 2. Normalize luciferase data
For each sheet and replicate, the pipeline:
- computes signal per area (`Volume / Area`)
- applies baseline correction using the 5% quantile
- normalizes values to a user-defined reference sample within each replicate
- appends processed data to a long-format `.csv` table

## Normalization procedure
For each replicate within each experiment:
1. **Compute raw signal per area**
   `VpA = Volume / Area`
2. **Baseline correction**
   The 5% quantile of `VpA` is used as a baseline and subtracted from all samples in the replicate.
3. **Reference-based normalization**
   Baseline-corrected values are divided by the mean value of a specified reference sample within the same replicate.
This yields normalized values that allow comparison across samples and experiments.

Example:
```bash
bash src/run_normalizer_MLO1vsEXO70.sh
```
This example script shows how to define:
- input .xlsx file
- output .csv file
- reference sample used for within-replicate normalization
You can modify the example shell script to process other experiments and reference sample combinations.

### 3. Run downstream analysis
Using a configuration file, the pipeline produces publication-ready analysis outputs such as plots and statistical summaries.
Customize your config.yml and run the R script by:
```bash
Rscript ./src/luc_visualizer.R
```

## Repository structure

```text
luc-leafwalker/
├── Data
├── LICENSE
├── Output
├── README.md
├── config
├── environment.yml
└── src
