# R/load_data.R
# Helpers for loading the multi-shard WOMD parquet tables.

#' Load all shards of a given table into a single tibble.
#' @param name One of: scenes, agents, agent_states, map_lanes,
#'   map_crosswalks, map_road_edges, traffic_signals.
load_table <- function(name) {
  files <- list.files(
    here::here("data/processed"),
    pattern = paste0("^", name, "_shard\\d+\\.parquet$"),
    full.names = TRUE
  )
  if (length(files) == 0) {
    stop("No files found for table '", name, "' in data/processed/")
  }
  arrow::open_dataset(files) |> dplyr::collect()
}

#' Load every WOMD table into a named list.
load_all <- function() {
  tables <- c("scenes", "agents", "agent_states",
              "map_lanes", "map_crosswalks", "map_road_edges",
              "traffic_signals")
  setNames(lapply(tables, load_table), tables)
}
