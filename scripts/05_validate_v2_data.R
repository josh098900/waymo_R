library(dplyr)
library(here)
source(here("R/load_data.R"))

d <- load_all()

# ---- Shape check ----
cat("\n--- ROW COUNTS ---\n")
for (n in names(d)) cat(sprintf("%-18s %s rows\n", n, format(nrow(d[[n]]), big.mark = ",")))

# ---- Shard distribution ----
cat("\n--- SCENES PER SHARD ---\n")
print(d$scenes |> count(shard_id))

cat("\n--- AGENTS PER SHARD by type ---\n")
print(d$agents |> count(shard_id, object_type) |> tidyr::pivot_wider(names_from = object_type, values_from = n, values_fill = 0))

# ---- New v2 fields: is_track_to_predict ----
cat("\n--- TRACKS TO PREDICT (new flag) ---\n")
print(d$agents |> filter(is_track_to_predict) |> count(shard_id, object_type))

cat("\n--- TRACKS TO PREDICT vs OBJECTS OF INTEREST ---\n")
print(d$agents |> count(is_track_to_predict, is_object_of_interest))

# ---- Traffic signals (new table) ----
cat("\n--- TRAFFIC SIGNAL STATE DISTRIBUTION ---\n")
print(d$traffic_signals |> count(state, sort = TRUE))

cat("\n--- SCENES WITH ANY TRAFFIC SIGNALS ---\n")
n_signal_scenes <- d$traffic_signals |> distinct(scene_id) |> nrow()
cat(n_signal_scenes, "of", nrow(d$scenes), "scenes have signal data\n")

# ---- Cyclist count across the bigger dataset ----
cat("\n--- CYCLIST COUNT ACROSS ALL SHARDS ---\n")
n_cyclists <- d$agents |> filter(object_type == "cyclist") |> nrow()
cat("Total cyclists:", n_cyclists, "\n")
