# luc-leafwalker
The repo provides a pipeline for formatting, normalizing, and analyzing data retrieved from luciferase complementation imaging (LCI) assays. It includes reproducible input generation, reference-based normalization, and downstream visualization/statistical evaluation.

## Overview
`luc-leafwalker` provides a workflow to prepare input tables, normalize luciferase complementation data, and generate downstream analyses and visualizations in a reproducible way. The pipeline is designed for experiments with multiple conditions, experiments, and replicates, and supports reference-based normalization within replicates.

## Workflow
The analysis consists of three main steps:

### 1. Create input `.xlsx` files
Raw experiment layouts are generated as structured Excel files containing sample combinations, experiment structure, and replicate setup.

### 2. Normalize luciferase data
For each sheet and replicate, the pipeline:
- computes signal per area (`Volume / Area`)
- applies baseline correction using the 5% quantile
- normalizes values to a user-defined reference sample within each replicate
- appends processed data to a long-format `.csv` table

### 3. Run downstream analysis
Using a configuration file, the pipeline produces publication-ready analysis outputs such as plots and statistical summaries.

## Normalization procedure
For each replicate within each experiment:
1. **Compute raw signal per area**
   `VpA = Volume / Area`
2. **Baseline correction**
   The 5% quantile of `VpA` is used as a baseline and subtracted from all samples in the replicate.
3. **Reference-based normalization**
   Baseline-corrected values are divided by the mean value of a specified reference sample within the same replicate.

This yields normalized values that allow comparison across samples and experiments.

## Repository structure

```text
luc-leafwalker/
├── src/
├── Data/
├── Output/
├── config.yml
└── README.md
