# Changelog

## Unreleased (0.3.0)

From agentmon, r2ui's first real app; every report is triaged in `docs/v03.md`.

- **Apps compose across files.** `R2UI.dashboard(name, extend: true)`, named rows (`row :top`), `order:` on rows and panels, and `R2UI.panel :memory, row: :top, order: 10 do ... end`; `R2UI.resource(name, extend: true)`. Extensions apply in any load order.
- **Shared sources.** `R2UI.source(:sample, every: 2) { |previous| ... }` and `source(from: :sample) { |s| ... }`: one fetch per interval per app, however many resources read it.
- **Dashboard DSL:** `focus :panel` (initial focus), `panel ..., width: 40` (fixed width), `refresh history: 900`, sparklines from a series the row carries (`sparkline: :trend`, `sparkline :p, series: :trend`), a series kept while its row is gone, `R2UI.with_registry { }`.
- **App:** `selected_rows(:panel)`, `view(width:, height:)`, `styles`, `key_pairs`; `rows`/`record` in panel item blocks; action handlers run on a Context, continue past a failing row, and `batch: true` gets every row.
- **Tables size text columns by content** instead of splitting spare width equally.
- **One home for formats:** `R2UI::Format` serves the dashboard and the CLI. `:bytes` switches unit at 1000 ("1.0K") and keeps the sign of negatives; new `:si_bytes`, `:duration`, `:age` formats and `:min`/`:max` aggregates; `Format.duration/plural/si_bytes`. The CLI's `bytes` stays decimal; `ibytes` is binary.
- **`help` without bubbles:** draws the same output itself when the bubbles gem isn't installed; full help lists actions and navigation keys.
- **CLI:** `table_lines`, `dashboard(registry:, ticks:)`, `exit_code(n)`, `on_exit` hook, `test_shell(height:)`, colour in `run_cli(color: true)` regardless of the test's stdout, summary shown above the description in help, String defaults converted for callable option types, better "did you mean" for short words.
- **Breaking:** defining a resource, dashboard or source again from a different place raises (pass `replace: true`); action handlers run with the Context as `self`; a per-row action no longer stops at the first failure; help shows summary and description.
- Fixed: grouped sparklines mis-summed series of different lengths.

## 0.2.0

- **Pure-Ruby drop-in for Bubble Tea.** `require "r2ui/drop_in"` makes `require "bubbletea"` and `require "lipgloss"` load r2ui's own versions of bubbletea 0.1.4 and lipgloss 0.2.2: no native extensions, no Go toolchain, no runtime dependencies.
- **bubbles runs unchanged.** bubbles 0.1.1 (and other pure-Ruby gems built on bubbletea/lipgloss) loads on top of the drop-in as-is.
- **Conformance harness** (`bin/conformance`, `conformance/`). Cases run in a pty against the real gems to record goldens, then against r2ui to check them; the screen is decoded and compared cell by cell, styles included. `conformance/ratchet/` lists the cases that must keep passing, and CI fails if one regresses.
- **Known intentional deviations** (listed in `conformance/concessions/`; the goldens still show upstream's behaviour):
  - Several keys arriving in one read become several events. Upstream makes one event from the first character of a read and drops the rest.
  - Bracketed paste is delivered whole, even when it spans several reads. Upstream can break a long paste into key events.

## 0.1.0

- ActiveAdmin-style DSL for terminal dashboards: `R2UI.resource` (source, refresh, scopes, `group_by` including trees, columns with formats and sparklines, filters, actions) and `R2UI.dashboard` (rows, panels, gauges, stats, sparklines, tables).
- `exe/r2ui` runs a dashboard file interactively or prints one frame with `--snapshot`.
