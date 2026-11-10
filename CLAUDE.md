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
