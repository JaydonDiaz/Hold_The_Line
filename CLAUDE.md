# Hold the Line — notes for working on this project

## Tests

- Every regression test lives in `tests/` and is committed with the change it covers.
  Never keep a test only in a scratch or temp folder: on macOS, `/private/tmp` is cleaned
  out after a few days (that's how an earlier set of 18 Classic tests was lost).
- Run them all with `tests/run_all.sh` (or `tests/run_all.sh units classic` for a few).
  Each `*_test.gd` runs headless at a fixed 60 fps and exits 1 on any failure.
- Performance is measured separately: `tests/perf_stress.gd` and `tests/perf_terrain.gd`.
- Tests and screenshots use temporary save paths (`Campaign.save_path = "user://..."`),
  never the player's own campaign save.
- Classic, Freeplay and the Tutorial must keep behaving as before unless a change is
  meant to touch them: `classic_test` and `units_test` cover them, and should pass the
  same on `main` and on a feature branch.

## Layout

- `main.tscn` is the only scene; `scripts/main.gd` is the game controller, built in code.
  main.gd holds only the battle's shared state (what several topics read and change: gold,
  wave, castle, layers, selection...) and the engine callbacks, each a one-line hand-off.
  Everything else is in `scripts/game/`, one file per topic, each a RefCounted holding
  `main` (typed, so Godot checks `main.x` there): setup, loop (every frame), battlefield
  (enemies/troops lookups, threats, graves), waves, castle_control (`main.castle_ctl`),
  missions, modes, hiring, groups, orders, formations (`main.formation_ctl`), input,
  effects, drawing. State only one topic uses lives in that topic's file.
- Call a topic through main: `main.waves.start_wave()`, `main.battlefield.get_enemies()`,
  `main.effects.sfx("horn")`; shared state stays `main.gold`, `main.wave`... Elsewhere
  `main` is untyped, so a wrong name only fails when the line runs: grep the topic files
  for the name before calling it.
- Tuning is in `scripts/data/`: `troops_data.gd`, `enemies_data.gd`, `castle_data.gd`, and
  `data.gd` (gold, difficulties, wave growth), which re-exports the rest as `Data.<NAME>`.
  The campaign's content is `scripts/data/campaign_data.gd`.
- Everything else is by topic: `troops/`, `enemies/`, `castle/`, `field/`, `campaign/`,
  `mission/` (battle rules), `art/`, `ui/`, `audio/`.
