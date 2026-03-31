#!/usr/bin/env bash

OUT="Data/raw/AtMLO1-EXO70_01.xlsx"
NUM_EXPERIMENTS=6
NUM_REPLICATES=4
NLUC="AtMLO1,AtMLO1,AtMLO1,AtMLO1,AtMLO1,AtMLO1,AtMLO1,AtMLO1,AtMLO1"
CLUC="AtEXO70A1,MmExoc7,ScExo70,AtEXO70G1,AtEXO70B1,AtEXO70B2,AtEXO70C1,AtEXO70C2,AtCAM2"
NORMALIZER="AtCAM2"

python src/luc_empty_input_generator.py \
  --out "$OUT" \
  --num-experiments "$NUM_EXPERIMENTS" \
  --num-replicates "$NUM_REPLICATES" \
  --nluc "$NLUC" \
  --cluc "$CLUC" \
  --normalizer "$NORMALIZER" \
  --no-spacers