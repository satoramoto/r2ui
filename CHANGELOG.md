# Changelog

Add entries under `## Unreleased`. The Release workflow moves them under the version's heading when it cuts a release (see docs/releasing.md).

## Unreleased

- **Pure-Ruby drop-in for Bubble Tea.** `require "r2ui/drop_in"` makes `require "bubbletea"` and `require "lipgloss"` load r2ui's own versions of bubbletea 0.1.4 and lipgloss 0.2.2: no native extensions, no Go toolchain, no runtime dependencies.
- **bubbles runs unchanged.** bubbles 0.1.1 (and other pure-Ruby gems built on bubbletea/lipgloss) loads on top of the drop-in as-is.
- **Conformance harness** (`bin/conformance`, `conformance/`). Cases run in a pty against the real gems to record goldens, then against r2ui to check them; the screen is decoded and compared cell by cell, styles included. `conformance/ratchet/` lists the cases that must keep passing, and CI fails if one regresses.
- **Known intentional deviations** (listed in `conformance/concessions/`; the goldens still show upstream's behaviour):
  - Several keys arriving in one read become several events. Upstream makes one event from the first character of a read and drops the rest.
  - Bracketed paste is delivered whole, even when it spans several reads. Upstream can break a long paste into key events.

## 0.1.0

- ActiveAdmin-style DSL for terminal dashboards: `R2UI.resource` (source, refresh, scopes, `group_by` including trees, columns with formats and sparklines, filters, actions) and `R2UI.dashboard` (rows, panels, gauges, stats, sparklines, tables).
- `exe/r2ui` runs a dashboard file interactively or prints one frame with `--snapshot`.
