# R2UI

ActiveAdmin-style DSL for terminal dashboards, in plain Ruby (no runtime dependencies). See README.md for the DSL.

## Layout

- `lib/r2ui/dsl/` — the DSL: `Resource` (+ `Builder`), `Dashboard` (+ row/panel builders), `Column`. Definitions are plain data; nothing here draws.
- `lib/r2ui/query.rb`, `search.rb` — rows → lines (scope, search, group, tree, sort). Pure functions; most logic tests live here.
- `lib/r2ui/widgets/`, `canvas.rb`, `renderer.rb` — drawing into a character grid.
- `lib/r2ui/app.rb` — `R2UI::App`, a Bubbletea model (init/update/view) that `R2UI.run` runs on the compat engine (`lib/r2ui/compat/bubbletea`); r2ui has no terminal loop of its own. `keys.rb` maps Bubbletea key messages to the core's key names; `feed.rb` fetches resources in the background.
- `lib/r2ui/extension.rb`, `context.rb`, `component.rb` — the extension point: `R2UI.extension(name) { ... }` registers DSL keywords, helpers, update handlers, panel items, hosted bubbles-style components and program options. Hook and user blocks run on a `Context`.
- `lib/r2ui/ext/*.rb` — one capability per file, loaded automatically (name order); each has `test/ext/<file>_test.rb`. `every.rb` and `view.rb` are the reference ones. `docs/dsl.md` is the design and the story list: a story adds only its own files there and edits nothing existing.
- `lib/r2ui/cli.rb` + `lib/r2ui/cli/` — the CLI toolkit (`require "r2ui/cli"`, a second product line beside the dashboards; it loads the compat engine and Lipgloss, not the dashboard DSL). `definition.rb`/`builder.rb` (commands DSL, plain data), `parser.rb`, `help.rb`, `runner.rb` (exit codes), `shell.rb` (IOs, TTY/colour decisions, `Theme`), `live.rb` (in-place region on the compat renderer), `prompt.rb` (inline Bubbletea prompts), `context.rb`, `helpers.rb`, `extension.rb` (`R2UI::CLI.extension`), `testing.rb` (`run_cli` for tests). `lib/r2ui/cli/ext/*.rb`: one capability per file, loaded automatically, each with `test/cli/ext/<file>_test.rb`; `tasks.rb` (output) and `confirm.rb` (prompt) are the reference ones. `docs/cli.md` is the design and the story list (ids `c01-...`). `examples/cli/deployer.rb` is a runnable tool.
- `examples/agents.rb` + `examples/agents/probe.rb` — the macOS Claude/Codex monitor; the probe is app code, not part of the gem.

## Tests

| Command | When |
|---|---|
| `bundle exec rake test` | After any change in `lib/` or `conformance/lib/` (~15 s: the compat and harness tests drive real ptys) |
| `bundle exec ruby -Itest -Ilib test/query_test.rb` | Targeted: one file |
| `bundle exec ruby -Itest -Ilib test/composition_test.rb` (and `source_test.rb`, `history_test.rb`, `app_v03_test.rb`, `widgets_table_test.rb`) | Targeted: the 0.3 core (registry composition, shared sources, history, app helpers, table widths) |
| `bundle exec ruby -Itest -Ilib test/ext/<file>_test.rb` | Targeted: one DSL extension while working on it |
| `bundle exec ruby -Itest -Ilib test/compat/bubbletea/<file>_test.rb` | Targeted: one compat test file while working in `lib/r2ui/compat/` |
| `bundle exec ruby -Itest -Ilib test/conformance/harness_test.rb` | Targeted: the harness (`vt_test.rb` for the decoder) while working in `conformance/lib/` |
| `bundle exec ruby -Itest -Ilib test/cli/<file>_test.rb` | Targeted: the CLI core (`parser`, `help`, `runner`, `shell`, `live`, `prompt`) while working in `lib/r2ui/cli/` |
| `bundle exec ruby -Itest -Ilib test/cli/ext/<file>_test.rb` | Targeted: one CLI story while working on it |
| `ruby examples/cli/deployer.rb deploy api --env production --force` (and again piped through `\| cat`) | After changing CLI output; shows the terminal and the plain rendering |
| `exe/r2ui --snapshot --width 140 --height 45 examples/agents.rb` | After changing drawing or the example; prints one real frame |
| `bin/conformance check --ratchet [filter]` | After any change in `lib/r2ui/compat/`; fails if a case in `conformance/ratchet/` fails (CI runs it). `bin/conformance check <filter>` diffs any case against its golden; cases in `conformance/concessions/` are reported as conceded, not failed |
| `bin/conformance record <filter>` | After adding or changing a case in `conformance/cases/`; needs the upstream gems installed. Case authors only; implementers never re-record. See `conformance/README.md` |

The interactive mode needs a terminal; tests drive it through `App#press` and `App#frame` instead.

CI (`.github/workflows/ci.yml`) runs `bundle exec rake test` on every PR; it is the final check.

## Bubble Tea drop-in (compat)

`require "r2ui/drop_in"` puts `lib/r2ui/compat/load_path/` first on `$LOAD_PATH`, so `require "bubbletea"` / `require "lipgloss"` load the pure-Ruby versions in `lib/r2ui/compat/`. The upstream gems (bubbletea 0.1.4, lipgloss 0.2.2, bubbles 0.1.1) are the spec: their behavior is right by definition. Install them locally with `gem install bubbletea bubbles lipgloss` to compare.

`factory/FACTORY.md` describes how this work is run (lanes, stations, which files each lane owns); `factory/LOG.md` records each run.

**Shared files** (change only through a small contract PR): `lib/r2ui/drop_in.rb`, `lib/r2ui/compat/load_path/`, `lib/r2ui.rb`, `lib/r2ui/extension.rb`, `lib/r2ui/context.rb`, `lib/r2ui/component.rb`, `lib/r2ui/registry.rb`, `lib/r2ui/source.rb`, `lib/r2ui/dsl/`, `lib/r2ui/feed.rb`, `lib/r2ui/history.rb`, `lib/r2ui/format.rb` (the formats both products use), `lib/r2ui/query.rb`, `lib/r2ui/app.rb`, `lib/r2ui/renderer.rb`, `lib/r2ui/widgets/table.rb`, `lib/r2ui/cli/ext/format.rb`, `docs/dsl.md`, `docs/v03.md`, `lib/r2ui/cli.rb`, `lib/r2ui/cli/*.rb` (the CLI core; not `cli/ext/`), `docs/cli.md`, `r2ui.gemspec`, `Gemfile`, `Rakefile`, `.github/workflows/ci.yml`, this file.

## Review checklist

Reviewers flag only real bugs and these rules, never style:
- Behavior differs from the upstream gem for the same call (the upstream gem is the spec).
- A lane edited files outside the ones its brief owns, or edited conformance goldens by hand.
- Terminal state isn't restored on every exit path (raw mode, alt screen, cursor, mouse, paste modes).
- New runtime dependencies (the gem has none).
- Tests that assert the implementation instead of upstream behavior.

## Releasing

Bump `lib/r2ui/version.rb`, then `bin/gem-push`: it builds the gem and runs `op run --env-file=.env -- gem push`. `.env` (gitignored; template in `.env.example`) holds a 1Password reference for `GEM_HOST_API_KEY`, resolved for that one command. It asks for Touch ID (and a one-time code if MFA is on), so the owner runs it, not an agent.

## Rules

- Keep the DSL free of drawing and the widgets free of DSL lookups; the renderer connects them.
- No Rails or ActiveSupport here; `active_tui` will build on this gem.
- Compat code must not load the upstream gems or their native extensions.
