# VRU–AV Interaction Analysis

Final year idea, analysing pedestrian and cyclist (vulnerable road user)
interactions with autonomous vehicles in the Waymo Open Motion Dataset.

## Status

In setup. Currently working with one validation_interactive shard.

## Structure

- `R/` — reusable functions
- `scripts/` — exploratory and one-off scripts
- `data/raw/` — WOMD tfrecord files (gitignored)
- `data/processed/` — converted parquet files (gitignored)
- `notebooks/` — Quarto exploratory notebooks
- `outputs/` — figures and tables for the dissertation
- `shiny/` — interactive dashboard
- `docs/` — written deliverables

## Reproducing

R packages locked via `renv`. After cloning:
\`\`\`r
renv::restore()
\`\`\`
