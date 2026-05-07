library(arrow)
library(dplyr)
library(here)


# Read all six tables
scenes         <- read_parquet(here("data/processed/scenes.parquet"))
agents         <- read_parquet(here("data/processed/agents.parquet"))
agent_states   <- read_parquet(here("data/processed/agent_states.parquet"))
map_lanes      <- read_parquet(here("data/processed/map_lanes.parquet"))
map_crosswalks <- read_parquet(here("data/processed/map_crosswalks.parquet"))
map_road_edges <- read_parquet(here("data/processed/map_road_edges.parquet"))

# Quick structural look
cat("Scenes:\n");       glimpse(scenes)
cat("\nAgents:\n");     glimpse(agents)
cat("\nAgent states:\n"); glimpse(agent_states)

# How many of each agent type across all scenes
agents |> count(object_type, sort = TRUE)

# How many cyclists?
n_cyclists <- agents |> filter(object_type == "cyclist") |> nrow()
n_pedestrians <- agents |> filter(object_type == "pedestrian") |> nrow()
cat("\nTotal cyclists across all scenes:", n_cyclists, "\n")
cat("Total pedestrians across all scenes:", n_pedestrians, "\n")

# How many scenes contain at least one cyclist
scenes_with_cyclists <- agents |>
  filter(object_type == "cyclist") |>
  distinct(scene_id) |>
  nrow()
cat("Scenes with at least one cyclist:", scenes_with_cyclists, "/", nrow(scenes), "\n")
