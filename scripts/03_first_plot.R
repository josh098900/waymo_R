# scripts/03_first_plot.R
# First visualisation of WOMD data: AV trajectory + a moving cyclist trajectory
# with surrounding map elements, picking the scene where some cyclist
# travelled the furthest.

library(arrow)
library(dplyr)
library(ggplot2)
library(here)

# ---- Load data ----
agents         <- read_parquet(here("data/processed/agents.parquet"))
agent_states   <- read_parquet(here("data/processed/agent_states.parquet"))
map_lanes      <- read_parquet(here("data/processed/map_lanes.parquet"))
map_crosswalks <- read_parquet(here("data/processed/map_crosswalks.parquet"))
map_road_edges <- read_parquet(here("data/processed/map_road_edges.parquet"))

# ---- Find the cyclist with the most movement across the whole shard ----
busiest <- agent_states |>
  filter(valid) |>
  inner_join(
    agents |> filter(object_type == "cyclist") |> select(scene_id, track_id),
    by = c("scene_id", "track_id")
  ) |>
  arrange(scene_id, track_id, timestep) |>
  group_by(scene_id, track_id) |>
  summarise(
    n_valid = n(),
    dist_m  = sum(sqrt(diff(center_x)^2 + diff(center_y)^2)),
    .groups = "drop"
  ) |>
  arrange(desc(dist_m)) |>
  slice(1)

target_scene <- busiest$scene_id
cyclist_id   <- busiest$track_id

cat("Picked scene:", target_scene, "\n")
cat("Cyclist track_id:", cyclist_id,
    "—", busiest$n_valid, "valid timesteps,",
    round(busiest$dist_m, 1), "m travelled\n")

# ---- Identify the AV in that scene ----
sdc_id <- agents |>
  filter(scene_id == target_scene, is_sdc) |>
  pull(track_id)

cat("AV track_id:", sdc_id, "\n")

# ---- Filter this scene's data ----
scene_states <- agent_states |>
  filter(scene_id == target_scene, valid)

av_path      <- scene_states |> filter(track_id == sdc_id)
cyclist_path <- scene_states |> filter(track_id == cyclist_id)

scene_lanes      <- map_lanes      |> filter(scene_id == target_scene)
scene_crosswalks <- map_crosswalks |> filter(scene_id == target_scene)
scene_edges      <- map_road_edges |> filter(scene_id == target_scene)

# ---- Plot ----
ggplot() +
  geom_path(data = scene_lanes,
            aes(x = x, y = y, group = feature_id),
            colour = "grey85", linewidth = 0.3) +
  geom_path(data = scene_edges,
            aes(x = x, y = y, group = feature_id),
            colour = "grey40", linewidth = 0.5) +
  geom_polygon(data = scene_crosswalks,
               aes(x = x, y = y, group = feature_id),
               fill = "khaki", alpha = 0.4) +
  geom_path(data = av_path,
            aes(x = center_x, y = center_y),
            colour = "steelblue", linewidth = 1) +
  geom_point(data = slice(av_path, 1),
             aes(x = center_x, y = center_y),
             colour = "steelblue", size = 3) +
  geom_path(data = cyclist_path,
            aes(x = center_x, y = center_y),
            colour = "firebrick", linewidth = 1) +
  geom_point(data = slice(cyclist_path, 1),
             aes(x = center_x, y = center_y),
             colour = "firebrick", size = 3) +
  coord_fixed() +
  labs(title = "AV (blue) and the most-mobile cyclist in the shard (red)",
       subtitle = paste("Scene:", target_scene),
       x = "x (m)", y = "y (m)") +
  theme_minimal()

# Save the plot as the project's first figure
ggsave(
  filename = here("outputs/figures/01_first_trajectory_plot.png"),
  width = 8, height = 8, dpi = 150
)
