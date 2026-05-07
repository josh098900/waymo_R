# R/build_features.R
# Functions for computing per-VRU summary stats and filtering to events.

#' Per-(scene, vru) summary statistics relative to the AV.
#'
#' @param d Output of load_all().
#' @param vru_type "cyclist" (default) or "pedestrian".
#' @return tibble with one row per (shard_id, scene_id, track_id).
build_vru_summary <- function(d, vru_type = "cyclist") {
  # AV per scene
  av_per_scene <- d$agents |>
    dplyr::filter(is_sdc) |>
    dplyr::select(shard_id, scene_id, av_track_id = track_id)

  av_states <- d$agent_states |>
    dplyr::inner_join(av_per_scene, by = c("shard_id", "scene_id")) |>
    dplyr::filter(track_id == av_track_id, valid) |>
    dplyr::select(shard_id, scene_id, timestep,
                  av_x = center_x, av_y = center_y,
                  av_vx = velocity_x, av_vy = velocity_y)

  av_movement <- av_states |>
    dplyr::arrange(shard_id, scene_id, timestep) |>
    dplyr::group_by(shard_id, scene_id) |>
    dplyr::summarise(av_movement_m = sum(sqrt(diff(av_x)^2 + diff(av_y)^2)),
                     .groups = "drop")

  # VRU metadata
  vru_info <- d$agents |>
    dplyr::filter(object_type == vru_type) |>
    dplyr::select(shard_id, scene_id, track_id,
                  is_track_to_predict, is_object_of_interest)

  # Per-timestep AV-VRU distances
  vru_av <- d$agent_states |>
    dplyr::inner_join(vru_info, by = c("shard_id", "scene_id", "track_id")) |>
    dplyr::filter(valid) |>
    dplyr::inner_join(av_states, by = c("shard_id", "scene_id", "timestep")) |>
    dplyr::mutate(
      distance_m = sqrt((center_x - av_x)^2 + (center_y - av_y)^2),
      vru_speed  = sqrt(velocity_x^2 + velocity_y^2),
      av_speed   = sqrt(av_vx^2 + av_vy^2)
    )

  # Per-(scene, vru) summary
  summary <- vru_av |>
    dplyr::arrange(shard_id, scene_id, track_id, timestep) |>
    dplyr::group_by(shard_id, scene_id, track_id,
                    is_track_to_predict, is_object_of_interest) |>
    dplyr::summarise(
      n_valid_steps      = dplyr::n(),
      min_dist_m         = min(distance_m),
      median_dist_m      = median(distance_m),
      max_dist_m         = max(distance_m),
      mean_vru_speed     = mean(vru_speed),
      max_vru_speed      = max(vru_speed),
      vru_movement_m     = sum(sqrt(diff(center_x)^2 + diff(center_y)^2)),
      timestep_min_dist  = timestep[which.min(distance_m)],
      .groups = "drop"
    )

  summary |> dplyr::left_join(av_movement, by = c("shard_id", "scene_id"))
}

#' Apply the formal interaction filter (distance + movement on both agents).
#'
#' @param summary Output of build_vru_summary().
#' @param max_dist_m Threshold on minimum distance (default 15 m).
#' @param min_movement_m Minimum movement required for both AV and VRU (default 5 m).
filter_interactions <- function(summary,
                                dist_threshold = 15,
                                movement_threshold = 5) {
  summary |>
    dplyr::filter(
      min_dist_m     <= dist_threshold,
      vru_movement_m >= movement_threshold,
      av_movement_m  >= movement_threshold
    )
}
