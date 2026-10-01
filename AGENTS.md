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
| `bin/conformance check --ratchet [filter]` | After any change in `lib/r2ui/compat/`; fails if a case in `conformance/ratchet/` fails (CI runs it). `bin/conformance check <filter>` diffs any case against its golden |
| `bin/conformance record <filter>` | After adding or changing a case in `conformance/cases/`; needs the upstream gems installed. Case authors only; implementers never re-record. See `conformance/README.md` |

The interactive mode needs a terminal; tests drive it through `App#press` and `App#frame` instead.

CI (`.github/workflows/ci.yml`) runs `bundle exec rake test` on every PR; it is the final check.

## Bubble Tea drop-in (compat)

`require "r2ui/drop_in"` puts `lib/r2ui/compat/load_path/` first on `$LOAD_PATH`, so `require "bubbletea"` / `require "lipgloss"` load the pure-Ruby versions in `lib/r2ui/compat/`. The upstream gems (bubbletea 0.1.4, lipgloss 0.2.2, bubbles 0.1.1) are the spec: their behavior is right by definition. Install them locally with `gem install bubbletea bubbles lipgloss` to compare.

`factory/FACTORY.md` describes how this work is run (lanes, stations, which files each lane owns); `factory/LOG.md` records each run.

**Shared files** (change only through a small contract PR): `lib/r2ui/drop_in.rb`, `lib/r2ui/compat/load_path/`, `lib/r2ui.rb`, `r2ui.gemspec`, `Gemfile`, `Rakefile`, `.github/workflows/ci.yml`, this file.

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
