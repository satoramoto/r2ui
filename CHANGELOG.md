# Changelog

Add entries under `## Unreleased`. To cut a release, the owner renames that heading to `## X.Y.Z` and adds a fresh `## Unreleased` above it (see docs/releasing.md).

## Unreleased

- `examples/diskinv.rb`: a Disk Inventory X clone (folder tree with subtree totals, a squarified treemap coloured by file kind, a kinds legend; click the treemap to select, `+`/`-` to zoom). Run `ruby examples/diskinv.rb [FOLDER]`.

## 0.2.0

### Upgrading from 0.1.0

- Dashboards now run on r2ui's pure-Ruby Bubble Tea engine: `R2UI::App` is a Bubbletea model (`init`/`update`/`view`) and `R2UI.run` runs it on the compat runner. The old terminal loop and raw key parser are gone; keys, search, sorting and folding behave as before.
- Plain `require "r2ui"` loads the engine by path and leaves `require "bubbletea"` / `require "lipgloss"` alone; the drop-in is opt-in.
- Dashboards default to the alt screen at 20 fps with synchronized output and line-diffed redraws, and only draw a frame when something changed (an update, new feed data, an animation, a flash, or once a second when idle).

### Bubble Tea drop-in and compat engine

- **Pure-Ruby drop-in for Bubble Tea.** `require "r2ui/drop_in"` makes `require "bubbletea"` and `require "lipgloss"` load r2ui's own versions of bubbletea 0.1.4 and lipgloss 0.2.2 (Style, borders, join/place, Table, List, Tree, colour profiles): no native extensions, no Go toolchain, no runtime dependencies.
- **bubbles runs unchanged.** bubbles 0.1.1 (and other pure-Ruby gems built on bubbletea/lipgloss) loads on top of the drop-in as-is.
- **Conformance harness** (`bin/conformance`, `conformance/`). Cases run in a pty against the real gems to record goldens, then against r2ui to check them; the screen is decoded and compared cell by cell, styles included. `conformance/ratchet/` lists the cases that must keep passing, and CI fails if one regresses.
- **Known intentional deviations** (listed in `conformance/concessions/`; the goldens still show upstream's behaviour):
  - Several keys arriving in one read become several events. Upstream makes one event from the first character of a read and drops the rest.
  - Bracketed paste is delivered whole, even when it spans several reads. Upstream can break a long paste into key events.
- r2ui-only renderer options, off by default so the engine matches upstream byte for byte: `synchronized:` (each frame wrapped in DEC mode 2026) and `line_diff:` (in the alt screen, write only the lines that changed).
- Fixes: renderer write errors after a hangup are ignored, as upstream; ticks scheduled from command threads are no longer lost.

### Dashboard DSL: extension point and extensions

- `R2UI.extension(name) { ... }` registers DSL keywords, helpers, message handlers (`on`, `observe`, `after_update`), panel items, hosted Bubbletea-style components, status hints and program options; blocks run on an `R2UI::Context` (`state`, `flash`, `quit`, `command`, ...). See docs/dsl.md.
- Panels can have no resource (`panel :clock, resource: nil do ... end`) and hold only extension items.
- Timers and commands: `every`, `after`, `async`, `batch` / `sequence`, `execute` (run a program in the foreground), `println`, `refresh` (fetch a resource now).
- Keys and messages: `on_key` (with help labels), your own messages with `on` and `emit`, declared initial `state`.
- Terminal: `inline` vs alt screen (and `enter_alt_screen` / `exit_alt_screen`), `window_title`, `mouse` with `on_click` and the wheel, `paste` / `on_paste`, `report_focus` with `on_focus` / `on_blur`, `on_resize` and `min_size`, `suspendable` / `on_resume` / `suspend`.
- Drawing: `view` (a panel item drawn by a block), `screen` (the whole view drawn by a block), `theme` (lipgloss styles for titles, borders, focus) and a `style` helper.
- Hosted bubbles components as panel keywords (needs the bubbles gem): `text_input`, `text_area`, `list`, `data_table`, `viewport`, `spinner`, `progress`, `countdown` (Timer), `stopwatch`, `paginate` (Paginator), `help`, `file_picker`.

### Dashboard views

- `R2UI::Motion` (`app.motion`, `motion` in extension blocks): tweens, pulses and ages evaluated per frame, with eases; frames keep drawing only while something moves. `app.motion.enabled = false` turns it off.
- `R2UI::Widgets::Glyphs`: braille line and area charts, partial-block bars, 24-bit heat colours and gradients, as plain ANSI strings for panel items.
- `table(columns: [...])` picks and orders a table's columns (sort cycling follows them); `table(motion: true)` marks moved and new lines in a left gutter and keeps the selection on its line across re-sorts.
- Column options: `style:` (a callable per value), `priority:` (lowest dropped first when columns don't fit), `sparkline: :braille` with `spark_width:`, `spark_max:` and `spark_style:`.
- `panel(..., border_style:)` colours a panel's border and title (a style or a callable); `row(height:)` accepts a callable evaluated each frame.

### Performance

- Dashboard frames cost a third or less of what they did (median, YJIT off: dense animating 14.3 → 5.0 ms, visual animating 24.4 → 5.4 ms), with identical screens. See docs/performance.md.
- Exact fast path for ANSI string width and truncation on valid UTF-8; Canvas cells hold codepoints with memoized widths and SGR prefixes; extension hooks cached; table cells and braille drawn without per-cell allocations.
- `R2UI::App` turns on the line-diff renderer, so animating frames write about 30% fewer bytes.
- `rake bench` / `rake bench:profile` measure per-frame cost by stage against a baseline; `bench/cpu.rb` measures a real program's CPU in a pty.

### CLI toolkit (`require "r2ui/cli"`)

- A second product line for command-line tools, inline (no alt screen): redrawn in place on a terminal, plain stable lines in a pipe or CI. See docs/cli.md and `examples/cli/deployer.rb`.
- Commands DSL: `R2UI.cli`, nested `command`s with `aliases`, `argument`, typed `option` (defaults, `in:` choices, required), `flag`, generated `--help`, usage errors with "did you mean".
- Runner and exit codes: 0 success, 1 error, 2 usage error, 130 ctrl+c; `abort!`, `halt`, `usage_error!`; a closed stdout ends quietly.
- `Shell` decides live redraw, interactivity (`TERM=dumb` is neither) and colour (`NO_COLOR`, `FORCE_COLOR`) once; `Theme` styles output; `R2UI::CLI.extension` adds keywords, helpers, hooks and help sections; `run_cli` for tests.
- Output helpers: `say`, `tasks` / `step`, `spin`, `progress` (rate and ETA), `info` / `success` / `warn` / `error` / `debug`, `box`, `pairs`, `tree`, `table`, `list`, `diff`, `pager`, `parallel` / `job`, `heading` / `done`, and `duration`, `bytes`, `plural`, `link`.
- Prompts (inline Bubbletea, line-based off a terminal): `confirm`, `ask`, `password`, `choose`, `choose_many`, `filter`, `edit` ($VISUAL / $EDITOR).
- Command keywords: `version` (`-V, --version`), `option ..., env:`, `config_file` (YAML/JSON, `--config`), `trace_option` (`--trace`), `example` (Examples in help), `reference_command` (Markdown reference), `color_option` (`--color` / `--no-color`), `completion` (bash, zsh, fish scripts), and a `dashboard` helper that opens an r2ui dashboard from a command (one snapshot frame off a terminal).

## 0.1.0

- ActiveAdmin-style DSL for terminal dashboards: `R2UI.resource` (source, refresh, scopes, `group_by` including trees, columns with formats and sparklines, filters, actions) and `R2UI.dashboard` (rows, panels, gauges, stats, sparklines, tables).
- `exe/r2ui` runs a dashboard file interactively or prints one frame with `--snapshot`.
