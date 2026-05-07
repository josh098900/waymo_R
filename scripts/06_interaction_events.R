library(dplyr)
library(tidyr)
library(ggplot2)
library(here)

source(here("R/load_data.R"))
source(here("R/build_features.R"))

d <- load_all()

# ---- Build summary across all shards ----
cyclist_summary <- build_vru_summary(d, vru_type = "cyclist")

cat("\nTotal cyclist instances:", nrow(cyclist_summary), "\n")
cat("TTP cyclists:           ", sum(cyclist_summary$is_track_to_predict), "\n")
cat("Non-TTP cyclists:       ", sum(!cyclist_summary$is_track_to_predict), "\n")

# ---- Threshold-sensitivity table ----
# In the sensitivity expand_grid block:
sensitivity <- expand_grid(
  max_dist     = c(5, 10, 15, 20),
  min_movement = c(0, 2, 5, 10)
) |>
  rowwise() |>
  mutate(n_events = nrow(filter_interactions(cyclist_summary,
                                             dist_threshold = max_dist,
                                             movement_threshold = min_movement))) |>
  ungroup() |>
  pivot_wider(names_from = min_movement, values_from = n_events,
              names_prefix = "move>=")

cat("\nEvent counts by (distance, movement) thresholds:\n")
print(sensitivity)

# ---- Defaults ----
# In the defaults block:
events <- filter_interactions(cyclist_summary,
                              dist_threshold = 15,
                              movement_threshold = 5)
cat("\nDEFAULT events (dist<=15m, movement>=5m on both):", nrow(events), "\n")
cat("  ...of which TTP-flagged:", sum(events$is_track_to_predict), "\n")

# ---- Visualise: distribution by TTP ----
ggplot(cyclist_summary, aes(x = min_dist_m, fill = is_track_to_predict)) +
  geom_histogram(binwidth = 5, position = "stack", colour = "white") +
  scale_fill_manual(values = c(`FALSE` = "grey70", `TRUE` = "steelblue"),
                    name = "Priority interactive (TTP)") +
  geom_vline(xintercept = 15, linetype = "dashed", colour = "firebrick") +
  annotate("text", x = 16, y = Inf, vjust = 2, hjust = 0,
           label = "15 m threshold", colour = "firebrick", size = 3.5) +
  labs(
    title = "AV–cyclist minimum distance, split by TTP flag",
    subtitle = sprintf("%d cyclist instances across 3 shards",
                       nrow(cyclist_summary)),
    x = "Minimum distance to AV (m)",
    y = "Count"
  ) +
  theme_minimal()

ggsave(here("outputs/figures/04_proximity_with_ttp.png"),
       width = 10, height = 5, dpi = 150)

# ---- Persist the events table for downstream sessions ----
arrow::write_parquet(events, here("data/processed/cyclist_events.parquet"))
cat("\nEvents table saved to data/processed/cyclist_events.parquet\n")
