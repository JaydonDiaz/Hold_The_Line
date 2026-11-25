# Performance baseline

Frame times from the stress tests (see `.claude/agents/perf.md` for how to run them).
Each row is one run: frame ms avg / p95 / p99 / max, frames over 33 ms, and draw calls and
drawn objects per frame. Lower is better. Runs wobble by about 5-10% between tries, so
compare like with like (same machine, same label, two or more runs).

## Machine and how it was run

- **Machine:** MacBook Pro, Apple M5 Pro (15 cores), 48 GB, macOS 27.2.1, Godot 4.7.2 (stable,
  official), Compatibility renderer (OpenGL), vsync off, fixed 60 fps simulation steps.
- **Date:** 2026-11-25.
- **Commits:** "before" is `f99f248` (phase5). "After" is f99f248 plus the changes listed
  under *Changes measured* (uncommitted when measured).
- **Labels:**
  - `typical`: 16 units, about 50 enemies, normal speed.
  - `heavy`: 40 fully upgraded units, every emplacement, the castle maxed, about 150
    enemies, 3x speed.
  - `*_phone`: the same fight played as on a phone held upright
    (`--resolution 400x866`): the phone layout, the game drawn at 640x1385 and scaled
    up, the ground painted at 1x.
  - **E-cores:** run with `taskpolicy -c background`, which keeps Godot on the Mac's slow
    efficiency cores (see *How close is this to a phone* below).
- Every run keeps the window on top (`--always-on-top`). macOS stops drawing a covered
  window, and the numbers are meaningless then; the summary now warns if it happened.

### Fix to the tools (read before comparing with older numbers)

Until this date, `perf_stress.gd`, `perf_terrain.gd` and `perf_south.gd` measured the
battle with the game's animated **splash screen drawn over it**. A windowed run opens on
the splash (only headless runs skip it), and the tools never closed it. The first rows
below, marked *splash*, are those runs. They are kept for the record but are not
comparable: the splash alone added about 1.5 ms and 2,000 drawn objects a frame.

## Runs

### Before (f99f248)

| Run | avg | p95 | p99 | max | >33 ms | draw calls | objects |
|---|---|---|---|---|---|---|---|
| heavy (*splash*) | 8.23 | 14.11 | 16.31 | 18.93 | 0 | 783 | 5737 |
| heavy (*splash*) | 8.38 | 15.08 | 17.26 | 20.21 | 0 | 782 | 5749 |
| typical (*splash*) | 6.61 | 9.46 | 10.03 | 11.08 | 0 | 702 | 5400 |
| typical (*splash*) | 6.56 | 9.48 | 10.07 | 11.16 | 0 | 689 | 5376 |
| heavy | 6.21 | 11.61 | 13.10 | 16.12 | 0 | 627 | 3862 |
| heavy | 6.49 | 11.97 | 15.22 | 19.66 | 0 | 620 | 3853 |
| typical | 4.83 | 6.91 | 8.34 | 11.02 | 0 | 586 | 3582 |
| typical | 5.18 | 8.27 | 9.04 | 12.86 | 0 | 561 | 3626 |
| heavy_phone | 6.84 | 11.18 | 12.72 | 15.64 | 0 | 619 | 3742 |
| heavy_phone | 6.87 | 12.19 | 13.72 | 16.40 | 0 | 626 | 3770 |
| typical_phone | 5.24 | 7.82 | 8.53 | 10.82 | 0 | 582 | 3434 |
| typical_phone | 4.95 | 6.81 | 8.08 | 9.68 | 0 | 556 | 3413 |
| typical_phone, E-cores | 20.98 | 30.97 | 34.22 | 64.43 | 33 | 561 | 3433 |
| typical_phone, E-cores | 21.39 | 27.85 | 31.68 | 40.67 | 7 | 552 | 3427 |
| heavy_phone, E-cores | 24.95 | 43.53 | 65.38 | 126.25 | 247 | 634 | 3815 |
| heavy_phone, E-cores | 28.73 | 48.07 | 54.75 | 72.65 | 488 | 649 | 3821 |

perf_terrain (`--resolution 640x1040`, 30 s, splash fixed):

| Run | avg | p95 | p99 | max |
|---|---|---|---|---|
| stonehollow_quarry | 8.59 | 10.47 | 11.97 | 14.22 |
| open | 7.64 | 9.84 | 10.45 | 12.85 |
| stonehollow_quarry (A/B run) | 7.74 | 8.98 | 10.11 | 10.86 |
| open (A/B run) | 7.42 | 9.13 | 10.29 | 18.37 |

### After

| Run | avg | p95 | p99 | max | >33 ms | draw calls | objects |
|---|---|---|---|---|---|---|---|
| heavy | 5.57 | 10.29 | 11.59 | 14.98 | 0 | 466 | 2147 |
| heavy | 5.66 | 10.63 | 12.33 | 21.79 | 0 | 475 | 2184 |
| typical | 4.10 | 5.54 | 6.82 | 8.99 | 0 | 431 | 1937 |
| typical | 4.02 | 6.54 | 8.29 | 10.40 | 0 | 374 | 1759 |
| heavy_phone | 6.33 | 11.63 | 13.02 | 15.63 | 0 | 472 | 2040 |
| heavy_phone | 6.06 | 10.68 | 12.83 | 17.41 | 0 | 473 | 2101 |
| typical_phone | 4.05 | 5.18 | 6.40 | 9.89 | 0 | 406 | 1713 |
| typical_phone | 4.24 | 5.70 | 6.79 | 14.45 | 0 | 401 | 1745 |
| typical_phone, E-cores | 17.65 | 23.93 | 30.52 | 93.99 | 8 | 394 | 1736 |
| typical_phone, E-cores | 17.16 | 22.15 | 27.11 | 48.04 | 4 | 384 | 1709 |
| heavy_phone, E-cores | 25.33 | 42.10 | 51.08 | 315.17 | 254 | 470 | 2057 |
| heavy_phone, E-cores | 26.19 | 46.88 | 52.39 | 56.86 | 236 | 477 | 2068 |

perf_terrain (`--resolution 640x1040`, 30 s):

| Run | avg | p95 | p99 | max |
|---|---|---|---|---|
| stonehollow_quarry | 7.49 | 9.13 | 10.10 | 11.81 |
| open | 7.15 | 8.53 | 9.14 | 11.57 |

(Terrain changes little: the castle is drawn the same way there, and these maps have few walls.)

### Where a frame goes (typical_phone)

The stress test now splits each frame into the scripts' `_process`, the `_draw` callbacks,
and rendering (with the renderer's own CPU time). Averages in ms:

| | scripts | `_draw` | rendering and the rest | renderer CPU |
|---|---|---|---|---|
| P-cores, before | 1.41-1.46 | 1.17-1.23 | 2.36-2.54 | 1.51-1.57 |
| P-cores, after | 1.29-1.36 | 0.89-0.91 | 1.87-1.96 | 1.05-1.06 |
| E-cores, before | 6.3-7.0 | 5.9 | 8.6-8.8 | 6.8-7.2 |
| E-cores, after | 6.1-6.6 | 4.5-4.6 | 6.1-6.9 | 4.9 |
| heavy_phone E-cores, before | 11.4-13.6 | 5.1-6.2 | 8.4-9.0 | 6.4-7.7 |
| heavy_phone E-cores, after | 12.0-13.3 | 5.7 | 7.1-7.6 | 5.6-5.9 |

In the heavy fight on phone-speed cores the scripts are half the frame: that's where
the next gains are (see the report).

## Changes measured

1. **The castle's stonework is painted once into a picture** (`scripts/castle/castle.gd`),
   like the ground: about 1,700 little blocks, lines and polygons become one textured
   rectangle. Painted again only when cracks show, the style changes or the field
   widens. Draw calls about -150 a frame, drawn objects about -1,700.
2. **Walls are drawn again only when their look changes** (`scripts/troops/barricade.gd`):
   a brick or stone wall was rebuilt from dozens of polygons every frame (about 0.2 ms
   each on the Mac). Hit, mended, upgraded, resized, felled or rebuilt, or the crew's
   hammers swinging, still redraw it; the energy wall and arcane seam animate every
   frame as before.
3. **The HUD sets font sizes and colours only when they change** (`scripts/ui/hud.gd`,
   `_font_size` / `_font_color`). Setting one, even to the same value, made the label lay
   its text out again, every frame. The castle cards' tooltips are written out again
   only when a price changes. HUD refresh: 124 to 86 us a frame (P-core).

Covered by `tests/redraw_test.gd`.

## How close is this to a phone

- **What the phone runs get right:** the phone's own code paths (layout, the game drawn
  at 640x1385 and scaled up, the ground at 1x), the same game logic and drawing, and on
  the E-cores a CPU roughly 3-4x slower than a P-core (about 21 ms a typical frame
  against 5). That's in the range of a mid-range phone's fast core running the web build,
  where WebAssembly and the GDScript interpreter in it are slower than native.
- **What they miss:**
  - WebGL. Each draw call in a browser passes the browser's checks and a translation
    layer (ANGLE), which costs several times a native OpenGL call. So draw calls matter
    more on a phone than these numbers show.
  - The phone's GPU. It's slower at filling pixels and blending, especially large
    see-through layers (night, weather, glows). The Compatibility renderer doesn't report
    GPU time, so these runs can't see it.
  - Heat. Phones slow down after a few minutes of load; a 30-second run doesn't show it.
  - The browser's own work: garbage collection, compositing, audio worklets.
- **Read it as:** the CPU side within about a factor of 2; the draw-call side likely
  better on the Mac than a real phone. The real check is a phone (see the report's
  next steps).
