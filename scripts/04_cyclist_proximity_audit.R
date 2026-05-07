library(arrow)
library(dplyr)
library(tidyr)
library(ggplot2)
library(here)
library(patchwork)



agents       <- read_parquet(here("data/processed/agents.parquet"))
agent_states <- read_parquet(here("data/processed/agent_states.parquet"))

#every (scene, cyclist) pair in the data
cyclist_pairs <- agents |>
  filter(object_type == "cyclist") |>
  select(scene_id, track_id) |>
  distinct()

cat("Total cyclist instances:", nrow(cyclist_pairs), "\n")

#av track id per scene (one per scene, by definition)
av_per_scene <- agents |>
  filter(is_sdc) |>
  select(scene_id, av_track_id = track_id)

cat("Scenes with an AV recorded:", nrow(av_per_scene), "\n")

# AV trajectories
av_states <- agent_states |>
  inner_join(av_per_scene, by = "scene_id") |>
  filter(track_id == av_track_id, valid) |>
  select(scene_id, timestep,
         av_x = center_x, av_y = center_y,
         av_vx = velocity_x, av_vy = velocity_y)

# Cyclist trajectories joined with AV at matching timesteps
cyclist_av_distances <- agent_states |>
  inner_join(cyclist_pairs, by = c("scene_id", "track_id")) |>
  filter(valid) |>
  inner_join(av_states, by = c("scene_id", "timestep")) |>
  mutate(
    distance_m = sqrt((center_x - av_x)^2 + (center_y - av_y)^2),
    cyclist_speed = sqrt(velocity_x^2 + velocity_y^2),
    av_speed = sqrt(av_vx^2 + av_vy^2)
  )

cat("Joined timestep rows:", nrow(cyclist_av_distances), "\n")

# Per (scene, cyclist) summary
cyclist_summary <- cyclist_av_distances |>
  group_by(scene_id, track_id) |>
  summarise(
    n_valid_steps = n(),
    min_dist_m    = min(distance_m),
    median_dist_m = median(distance_m),
    max_dist_m    = max(distance_m),
    mean_cyclist_speed = mean(cyclist_speed),
    max_cyclist_speed  = max(cyclist_speed),
    cyclist_movement_m = sum(sqrt(diff(center_x)^2 + diff(center_y)^2)),
    .groups = "drop"
  ) |>
  arrange(min_dist_m)

print(cyclist_summary, n = 10)



ggplot(cyclist_summary, aes(x = min_dist_m)) +
  geom_histogram(binwidth = 5, fill = "steelblue", colour = "white") +
  geom_vline(xintercept = 10, linetype = "dashed", colour = "firebrick") +
  annotate("text", x = 11, y = Inf, vjust = 2,
           label = "10 m provisional threshold",
           hjust = 0, colour = "firebrick", size = 3.5) +
  labs(
    title = "Minimum AV–cyclist distance per (scene, cyclist) pair",
    subtitle = paste0("n = ", nrow(cyclist_summary), " cyclists across ",
                      n_distinct(cyclist_summary$scene_id), " scenes"),
    x = "Minimum distance (m)",
    y = "Count"
  ) +
  theme_minimal()

ggsave(
  filename = here("outputs/figures/02_min_distance_distribution.png"),
  width = 8, height = 5, dpi = 150
)


# Load map layers
map_lanes      <- read_parquet(here("data/processed/map_lanes.parquet"))
map_crosswalks <- read_parquet(here("data/processed/map_crosswalks.parquet"))
map_road_edges <- read_parquet(here("data/processed/map_road_edges.parquet"))

# The 6 closest (scene, cyclist) pairs, with a case label
top6 <- cyclist_summary |>
  slice_min(min_dist_m, n = 6) |>
  mutate(case_label = sprintf("Case %d — %.2f m", row_number(), min_dist_m)) |>
  mutate(case_label = factor(case_label, levels = case_label))  # preserve order

# Build the per-layer faceted datasets
top6_av <- top6 |>
  select(scene_id, case_label) |>
  inner_join(av_states, by = "scene_id")

top6_cyclist <- top6 |>
  select(scene_id, track_id, case_label) |>
  inner_join(
    agent_states |>
      filter(valid) |>
      select(scene_id, track_id, timestep, center_x, center_y),
    by = c("scene_id", "track_id")
  )

top6_lanes      <- top6 |> select(scene_id, case_label) |>
  inner_join(map_lanes, by = "scene_id")
top6_edges      <- top6 |> select(scene_id, case_label) |>
  inner_join(map_road_edges, by = "scene_id")
top6_crosswalks <- top6 |> select(scene_id, case_label) |>
  inner_join(map_crosswalks, by = "scene_id")

library(patchwork)

# Function to plot one case
plot_case <- function(scene, track, label) {
  av  <- av_states     |> filter(scene_id == scene)
  cyc <- agent_states  |> filter(scene_id == scene, track_id == track, valid)
  ln  <- map_lanes     |> filter(scene_id == scene)
  rd  <- map_road_edges|> filter(scene_id == scene)
  cw  <- map_crosswalks|> filter(scene_id == scene)

  ggplot() +
    geom_path(data = ln, aes(x, y, group = feature_id),
              colour = "grey85", linewidth = 0.3) +
    geom_path(data = rd, aes(x, y, group = feature_id),
              colour = "grey40", linewidth = 0.4) +
    geom_polygon(data = cw, aes(x, y, group = feature_id),
                 fill = "khaki", alpha = 0.4) +
    geom_path(data = av, aes(av_x, av_y),
              colour = "steelblue", linewidth = 0.9) +
    geom_point(data = slice_min(av, timestep, n = 1),
               aes(av_x, av_y), colour = "steelblue", size = 2) +
    geom_path(data = cyc, aes(center_x, center_y),
              colour = "firebrick", linewidth = 0.9) +
    geom_point(data = slice_min(cyc, timestep, n = 1),
               aes(center_x, center_y), colour = "firebrick", size = 2) +
    coord_fixed() +
    labs(title = label, x = NULL, y = NULL) +
    theme_minimal() +
    theme(axis.text = element_blank(),
          axis.ticks = element_blank(),
          panel.grid.minor = element_blank(),
          plot.title = element_text(face = "bold", size = 9))
}

# Build all 6 plots, then arrange them
plots <- purrr::pmap(
  top6 |> select(scene_id, track_id, case_label),
  ~ plot_case(..1, ..2, as.character(..3))
)

combined <- patchwork::wrap_plots(plots, ncol = 3) +
  plot_annotation(
    title    = "Six closest AV–cyclist approaches",
    subtitle = "Blue = AV trajectory, red = cyclist trajectory, dots = start positions"
  )

print(combined)

ggsave(
  filename = here("outputs/figures/03_six_closest_approaches.png"),
  plot     = combined,
  width = 12, height = 8, dpi = 150
)

