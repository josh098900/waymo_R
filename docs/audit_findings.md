# Session 3 — Cyclist Proximity Audit

## Source
One shard: `validation_interactive.tfrecord-00000-of-00150`

## Headline numbers
- 282 scenes
- 19,021 agents (16,395 vehicles, 2,501 pedestrians, 125 cyclists)
- 65 of 282 scenes contain at least one cyclist (23%)

## Cyclist–AV minimum distance distribution
| Threshold | Cyclists within |
|-----------|-----------------|
| < 5 m     | 11              |
| < 10 m    | 26              |
| < 15 m    | 39              |
| < 20 m    | 43              |

Marginal distribution shows a natural break between [10–15m) (n=13)
and [15–20m) (n=4), suggesting **15m as a defensible interaction
threshold**. Within 15m: 39 candidate cyclist–AV interaction events
in this shard.

## Qualitative observations from top-6 closest cases
- 1 of 6 cases is a clear "crossing" interaction at a junction (Case 5).
- 1 of 6 is parallel road-sharing with gentle convergence (Case 3).
- The remaining 4 likely involve one or both agents being stationary
  for the bulk of the 20s window.

## Methodological implications
- **Distance threshold alone is insufficient.** A meaningful subset of
  close-approach cases involve stationary agents (parked vehicles or
  paused cyclists), which are co-presence, not interaction.
- **Add a movement filter:** both AV and cyclist must move at least
  N metres during the 20s window for the case to qualify. N to be
  calibrated (provisional 5–10m).
- The `tracks_to_predict` field was not extracted in our initial
  conversion. The interactive split labels priority interacting agents
  through this field rather than `objects_of_interest`. Should be
  added in the next conversion run.

## Artefacts
- `outputs/figures/02_min_distance_distribution.png` — proximity histogram
- `outputs/figures/03_six_closest_approaches.png` — top-6 panel
- `data/processed/cyclist_summary.parquet` — per-(scene, cyclist) summary

## Session 4 — v2 Converter & Scale-Up

### Coverage
3 shards (validation_interactive, indices 0–2): 850 scenes, 58,076 agents,
5.3M agent states, 478,482 traffic signal observations.

### Key new fields
- `is_track_to_predict` (priority interactive flag): cyclists ✓
  60 TTP cyclists across 3 shards (15/21/24 per shard).
- `traffic_signals` table populated and meaningful:
  78% of signal states known (`stop` 38%, `go` 22%, arrow variants 16%).
  588 of 850 scenes have signal data.

### Methodological updates
- Use `is_track_to_predict` as the primary interaction-candidate filter.
  `is_object_of_interest` is a side label — much smaller cohort and
  partially disjoint from TTP.
- Signalised vs unsignalised stratification is feasible across ~70%
  of scenes.

### Extrapolation to full validation_interactive split (150 shards)
- ~42,500 scenes
- ~3,000 priority interactive cyclists
- ~24M traffic signal observations

## Session 5 — Formal Interaction Events

### Definition
An *interaction event* is a (scene, cyclist) pair where:
- minimum AV–cyclist distance ≤ 15 m
- both AV and cyclist moved ≥ 5 m during the 20 s window

### Count
58 events across 3 shards. Extrapolates to ~2,900 across the
full 150-shard validation_interactive split.

### TTP vs distance
TTP-flagged cyclists overwhelmingly concentrate in the [0,15) m
bins, but ~10 of 60 TTP cyclists are at 20–35 m and never
physically approached the AV. TTP captures Waymo's prediction
importance, not physical proximity. We use **distance + movement**
as the primary filter; TTP is retained as a column for sensitivity
analysis but is not the definition.
