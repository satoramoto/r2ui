# R2UI

ActiveAdmin-style DSL for terminal dashboards, in plain Ruby (no runtime dependencies). See README.md for the DSL.

## Layout

- `lib/r2ui/dsl/` — the DSL: `Resource` (+ `Builder`), `Dashboard` (+ row/panel builders), `Column`. Definitions are plain data; nothing here draws.
- `lib/r2ui/query.rb`, `search.rb` — rows → lines (scope, search, group, tree, sort). Pure functions; most logic tests live here.
- `lib/r2ui/widgets/`, `canvas.rb`, `renderer.rb` — drawing into a character grid.
- `lib/r2ui/app.rb`, `terminal.rb`, `keys.rb`, `feed.rb` — the run loop, raw terminal, input, background fetching.
- `examples/agents.rb` + `examples/agents/probe.rb` — the macOS Claude/Codex monitor; the probe is app code, not part of the gem.

## Tests

| Command | When |
|---|---|
| `bundle exec rake test` | After any change in `lib/` (well under a second) |
| `bundle exec ruby -Itest -Ilib test/query_test.rb` | Targeted: one file |
| `exe/r2ui --snapshot --width 140 --height 45 examples/agents.rb` | After changing drawing or the example; prints one real frame |

The interactive mode needs a terminal; tests drive it through `App#press` and `App#frame` instead.

## Rules

- Keep the DSL free of drawing and the widgets free of DSL lookups; the renderer connects them.
- No Rails or ActiveSupport here; `active_tui` will build on this gem.
