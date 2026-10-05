# Performance

What a dashboard frame costs, how to measure it, and what was done about it (October 2026, on the
`proto/design-directions` prototypes: Motion, Glyphs, braille columns, table motion).

## Running the bench

| Command | What it does |
|---|---|
| `bundle exec rake bench` | Draws the two fixture dashboards (`bench/fixtures.rb`) at 100×50, YJIT off and on (each in its own child process), and prints per-frame cost by stage with the delta against `bench/results/baseline.json`. Saves `bench/results/latest.json` (not committed). About 80 s. |
| `bundle exec rake bench:baseline` | The same, then saves the run as the baseline. |
| `bundle exec rake bench:profile` | stackprof CPU and allocation tops for each fixture × scenario, and a vernier profile per run in `bench/results/profiles/` (open in https://vernier.prof for the flame graph). `ruby bench/profile.rb --only dense --scenario animating --yjit` narrows it. |
| `ruby bench/cpu.rb -- COMMAND...` | A real program's CPU in a 100×50 pty: CPU time over 20 s after a 5 s warm-up (`--cols --rows --warmup --seconds`). Kills the program on every exit path. |

The fixtures stand in for agentmon's `--layout dense` and `--layout visual`: tables of 60 processes
and 8 sessions with braille sparkline columns, 24-bit heat-coloured cells and motion gutters; panel
items drawn as ANSI strings (meters with tweened bars and pulsing values, braille sparks and area
charts, stat grids) the way agentmon draws them, including its string cache. Data comes from a
deterministic `World`, time from an injected clock; nothing reads the machine.

Each frame is timed in three stages:

- **draw**: `App#frame` (layout, tables, Query, extension items) into a `Canvas`;
- **ansi**: `Canvas#ansi_lines.join("\n")`, the view string;
- **output**: the compat `Renderer#render` writing to a byte-counting sink with the options
  `R2UI::App::PROGRAM_OPTIONS` gives it.

Scenarios: **steady** (nothing changed: an idle redraw), **animating** (a sample arrived 1-3 frames
ago, tweens, pulses and gutter marks moving, 10 fps), **data_change** (the first frame after a
sample: feeds refreshed, Query re-runs). 60 measured frames after 30 warm-up ones; medians and p95.

Every frame's output is also fed to the conformance VT emulator: the `screen` column says whether
the terminal showed exactly the same screens as the baseline run. Every fix below kept `same` on
all 12 rows (and the view strings identical), so the terminal shows the same thing; only the bytes
written changed (line diff).

## Baseline vs final

Median ms per frame (total of the three stages), Ruby 3.4.3 arm64, this Mac:

| frame | YJIT off before | after | YJIT on before | after |
|---|---|---|---|---|
| dense steady | 5.46 | 2.95 | 3.06 | 1.73 |
| dense animating | 14.32 | 5.02 | 7.96 | 2.36 |
| dense data_change | 14.58 | 5.09 | 7.94 | 2.42 |
| visual steady | 8.39 | 3.11 | 5.50 | 1.76 |
| visual animating | 24.37 | 5.42 | 12.71 | 2.58 |
| visual data_change | 24.74 | 6.89 | 13.89 | 3.61 |

By stage, YJIT off (ms median; allocations and bytes per frame):

| frame | draw | ansi | output | p95 total | allocs | bytes written |
|---|---|---|---|---|---|---|
| dense steady | 4.60 → 2.41 | 0.74 → 0.51 | 0 → 0 | 12.56 → 3.37 | 18322 → 4506 | 0 → 0 |
| dense animating | 6.32 → 3.15 | 0.62 → 0.53 | 7.29 → 1.31 | 15.05 → 6.22 | 52537 → 5671 | 14112 → 9996 |
| dense data_change | 6.61 → 3.06 | 0.63 → 0.53 | 7.43 → 1.49 | 16.72 → 6.01 | 52527 → 5785 | 14057 → 11455 |
| visual steady | 7.78 → 2.58 | 0.59 → 0.54 | 0 → 0 | 8.87 → 3.88 | 37661 → 4448 | 0 → 0 |
| visual animating | 9.69 → 3.16 | 0.64 → 0.55 | 13.99 → 1.74 | 28.39 → 6.59 | 94081 → 5653 | 16695 → 12112 |
| visual data_change | 10.48 → 4.11 | 0.63 → 0.53 | 13.54 → 2.19 | 28.90 → 8.00 | 98578 → 10480 | 16606 → 14563 |

`bench/results/baseline.json` is the before run, `bench/results/final.json` the after run.

### agentmon end to end

agentmon's own CPU (`ruby bench/cpu.rb -- bundle exec exe/agentmon ...` from the agentmon
prototype worktree: 100×50 pty, 5 s warm-up, CPU time over 20 s). "Before" loads r2ui at the
bench baseline commit; "after" this branch. Single runs; another session was using the machine,
so treat ±1 point as noise.

| agentmon | before | after | after, YJIT on |
|---|---|---|---|
| default dashboard | 5.5% | 5.8% | 5.8% |
| default, `--no-motion` | 5.1% | – | – |
| `--layout dense` | 10.8% | 6.8% | 6.1% |
| `--layout dense --no-motion` | 6.2% | 5.2% | – |
| `--layout visual` | 13.6% | 6.9% | 5.6% |
| `--layout visual --no-motion` | 7.7% | 6.2% (8.6% in a noisier run) | – |

Target (dense and visual with motion at most about 2× the default dashboard): met, they are now
within about 1.2× of it. The default dashboard's ~5% is mostly agentmon's sampling, not drawing.

## Hotspots (before) and fixes

Profiles of the baseline (`rake bench:profile`, YJIT off; shares are of non-GC CPU samples, GC was
about 8% of frame time measured with GC.stat):

1. **`Compat::Tea::ANSI.string_width` / `first_grapheme_cluster` / `decode_runes`**
   (`lib/r2ui/compat/bubbletea/ansi.rb`, string_width at line 200, the cluster decode at 290-330):
   65% of CPU in dense animating, 77% in visual animating, 61% of all allocations. Every non-ASCII
   character (box drawing, braille, blocks) decoded 8 runes into arrays, packed them, ran `\X` and
   summed: ~30 objects per character. Called per line by the compat renderer, per character by
   `Canvas#write_ansi`, and by apps measuring strings.
   **Fix:** an exact fast path for valid UTF-8: one StringScanner `skip(/\X/)` per cluster, one-rune
   clusters decoded from the bytes, cluster and character widths memoized (bounded); invalid UTF-8
   keeps the old path. Same results for every input (equivalence test against the old code over
   1500 generated strings, plus the upstream gem comparisons). A realistic 100-cell line: 1768 →
   3 allocations, 462 → 55 µs. **Gain:** dense animating 14.3 → 7.7 ms, visual animating 24.4 →
   10.1 ms (YJIT off).
2. **`Canvas`** (`lib/r2ui/canvas.rb`): `write` (`each_char.first(n).each_with_index`, line 70),
   `write_ansi` (string_width per character, lines 55-56) and `ansi_lines` (an interpolated SGR
   prefix per style change, line 93): together ~55% of CPU in dense steady and ~32% of its
   allocations (`String#each_char`). **Fix:** cells hold Integer codepoints, per-codepoint widths
   memoized (printable ASCII is 1), SGR prefixes memoized per style, lines built with `<<` into a
   pre-sized String; same output (equivalence test against the old Canvas). **Gain:** dense
   animating 7.7 → 6.9 ms, visual animating 10.1 → 7.1 ms, visual steady 6.0 → 3.7 ms.
3. **Draw-stage allocations**: `Extensions.hooks` re-sorted every call (~630 objects per frame,
   `lib/r2ui/extension.rb`); `Glyphs.heat` allocated a key and took a mutex twice per heat cell,
   `Glyphs.fg`/`Motion.rgb` re-parsed hex per call (`lib/r2ui/widgets/glyphs.rb`,
   `lib/r2ui/motion.rb`); `Table#cell` built segment arrays per cell (Table#cell ~20% of dense
   steady CPU, `lib/r2ui/widgets/table.rb`); `braille_line` built arrays; `History#sum` copied a
   single series. **Fix:** hooks cached and frozen (invalidated on any hook/extension change),
   heat/fg/bg/rgb memoized, table cells written straight to the canvas, braille via lookup
   tables, single-series sum returned as is. **Gain:** dense animating 6.9 → 5.4 ms, visual
   animating 7.1 → 6.1 ms; draw allocations 7.3 K → 4.3 K (dense steady).
4. **Compat renderer rewriting every line** (`lib/r2ui/compat/bubbletea/renderer.rb:63-66`): every
   frame wrote and re-measured all 50 lines. **Fix:** an opt-in `line_diff` (r2ui addition, like
   `synchronized`; off by default so the compat engine still matches upstream byte for byte): in the
   alt screen with a known size, a frame with as many lines as the last one writes only the changed
   lines, each placed with CUP (or CR LF after the line above). `clear`, a real size change,
   `alt_screen=` and the exec extension's repaint make the next frame whole. `R2UI::App` turns it
   on (`PROGRAM_OPTIONS`). The runner now also tells the renderer it is in the alt screen when
   line_diff is on (it entered the alt screen before the renderer existed, so the renderer used to
   draw inline-style there). **Gain:** output stage dense animating 1.9 → 1.3 ms and 14.1 → 10.0 KB,
   visual animating 2.5 → 1.7 ms and 16.7 → 12.1 KB.

Not done, on purpose: caching Query results per feed version (small: ~1-2% of draw; it would also
freeze reader-computed columns such as ages between refreshes).

## YJIT

Measured, not enabled by r2ui. With YJIT the bench frames are about 2× cheaper again (dense
animating 5.0 → 2.4 ms), but end to end agentmon moves by about a point (dense 6.8% → 6.1%,
visual 6.9% → 5.6%), within noise of its sampling cost, and YJIT is process-wide with a memory
cost. A library should not flip it for its host process; apps that want it run with
`RUBY_YJIT_ENABLE=1` or call `RubyVM::YJIT.enable` at startup.

## What's left

- `ANSI.string_width` is still the top CPU frame in animating frames (~15-20% of samples): the
  compat renderer measures each changed line byte by byte in Ruby, and apps measure their strings
  with it (agentmon's `visible_width`). A further fast path for SGR-only lines would need the same
  exactness proof.
- Animating frames still rewrite most lines: gutter marks fade every frame on every moved row, and
  tweened meters change a few cells. Fewer bytes would need a cell-level diff (cursor moves within
  a line) in the renderer.
- `Canvas#write`/`ansi_lines` and `Table#draw_cell` are the rest of the draw stage; GC is about a
  third of what is left in the profiles.
- Things that write to the terminal behind the renderer's back (`Bubbletea.clear_screen`, a
  `PutsCommand` to stderr, an app printing to stdout, `Program#enter_alt_screen` called directly)
  would leave a line-diffed screen stale until those lines change; the full redraw had the same
  problem for unchanged frames.
- `History#sum` misaligns grouped series of different lengths (a shorter series wraps to its newest
  values); kept as is, since the bench's job was to change nothing drawn.
