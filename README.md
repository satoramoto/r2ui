# R2UI

ActiveAdmin-style DSL for terminal dashboards. You declare resources, scopes, groupings, columns and actions; R2UI draws the tables, gauges and sparklines, and handles keys, search, sorting and folding.

Pure Ruby, no runtime dependencies.

```ruby
R2UI.resource :process do
  source { MyProbe.processes }        # any array of hashes, Data/Struct objects or models
  refresh every: 2                    # seconds, or an ActiveSupport::Duration
  key :pid, parent: :ppid             # identity, plus parent for tree grouping

  scope :agents, default: true, &:agent
  scope :all

  group_by :agent, label: "Session"   # same value → one line, numbers summed
  group_by :cwd, label: "Directory"
  group_by :parent, tree: true        # tree; each node's numbers include its subtree

  index do
    column :pid, format: :id
    column :name
    column :cwd, format: :short_path
    column :cpu, format: :percent, sparkline: true, sort: :desc
    column :rss, label: "Memory", format: :bytes
  end

  filter :name, :cwd                  # what "/" free text matches

  action :terminate, key: "K", confirm: true do |process|
    Process.kill(:TERM, process.pid)
  end
end

R2UI.dashboard do
  row height: 15 do
    panel :memory, span: 1 do
      gauge :used, of: :total
      stat :wired, :compressed, :swap_used
      sparkline :pressure
    end
    panel :sessions, resource: :process, span: 2 do
      table scope: :agents, group_by: :agent
    end
  end
  row { panel :process }              # no block: the resource's full index
end
```

## Run it

```sh
exe/r2ui examples/agents.rb              # interactive
exe/r2ui --snapshot examples/agents.rb   # print one frame and exit
```

`examples/agents.rb` is a macOS monitor for Claude and Codex runs. It groups processes by agent session (the outermost `claude`/`codex` process, or the desktop app), by working directory, by name or as a tree. It also breaks memory down the way Activity Monitor does: app, wired and compressed memory, compression ratio, swap, swap-out and compression rates, and memory pressure.

## Keys

| Key | Does |
|---|---|
| `tab` / `shift-tab` | Focus next / previous panel |
| `[` `]` | Previous / next scope |
| `g` | Cycle grouping (off → each `group_by` → off) |
| `s` / `S` | Next sort column / reverse |
| `/` | Search: free text, or `cpu>5`, `rss>=500M`, `cwd~starseed`; `esc` clears |
| `enter` / `space` | Fold or unfold a tree node |
| `z` | Zoom the focused panel |
| action keys | Run the action on the selected line (all its rows when grouped) |
| `q` | Quit |

## Formats

`:text`, `:id`, `:integer`, `:number`, `:percent`, `:bytes`, `:bytes_per_sec`, `:ratio`, `:short_path`. The format decides display, alignment, how grouped lines aggregate (`:sum`, `:count` or a single shared value) and how search operands are parsed (`500M`, `5%`).

## Extensions

Everything a Bubble Tea program can do, a dashboard can declare: `on_key`, `state`, `every`/`after`/`async`, `emit`, `execute`, `println`, `inline` vs alt screen, `window_title`, `mouse`, `paste`, `on_resize`, `theme`, `view` and `screen` blocks, and bubbles components as panel keywords (`text_input`, `list`, `data_table`, `viewport`, `spinner`, `progress`, ...). Each is one file in `lib/r2ui/ext/` registered with `R2UI.extension`, the same hook you use to add your own. See [docs/dsl.md](docs/dsl.md).

```ruby
R2UI.dashboard do
  state deploys: 0
  on_key("d", help: "deploy") { state[:deploys] += 1; flash "deploying" }
  row height: 3 do
    panel(:status, resource: nil) { view { "#{state[:deploys]} deploys" } }
  end
end
```

## Views: motion, glyphs, columns

For dense monitors: `R2UI::Motion` tweens, pulses and ages values while frames draw (and stops drawing when nothing moves); `R2UI::Widgets::Glyphs` draws braille charts, partial-block bars and heat colours as ANSI strings. Tables take `columns:` to pick and order columns and `motion: true` to mark moved rows; columns take `style:`, `priority:` and `sparkline: :braille`; panels take `border_style:`. Frame costs and how they're measured: [docs/performance.md](docs/performance.md).

## CLI toolkit

`require "r2ui/cli"` builds command-line tools that look like npm, pnpm or bun on a terminal and print plain, stable lines in a pipe or CI: a commands DSL with generated help and exit codes, task lists, spinners, progress bars, log levels, boxes, tables, trees, diffs, prompts (`confirm`, `ask`, `choose`, `filter`, ...), `--version`, env/config-file options, shell completion, and a command that opens a dashboard. See [docs/cli.md](docs/cli.md) and `examples/cli/deployer.rb`.

```ruby
require "r2ui/cli"

R2UI.cli "deployer" do
  command :deploy do
    argument :app
    run do
      tasks do
        step("Building") { build(args[:app]) }
        step("Uploading") { upload }
      end
    end
  end
end.start
```

## Drop-in for Bubble Tea

r2ui also ships pure-Ruby versions of the Charm gems bubbletea 0.1.4 and lipgloss 0.2.2: no native extensions, nothing to compile. Require `r2ui/drop_in` before anything else, and existing programs, including ones built on bubbles 0.1.1, run unchanged:

```ruby
require "r2ui/drop_in"   # first: `require "bubbletea"` / `"lipgloss"` now load r2ui's versions
require "bubbletea"
require "bubbles"        # the real bubbles gem, unmodified

class Prompt
  include Bubbletea::Model

  def initialize
    @input = Bubbles::TextInput.new
    @input.placeholder = "Your name"
    @input.focus
  end

  def init = [self, nil]

  def update(message)
    return [self, Bubbletea.quit] if message.is_a?(Bubbletea::KeyMessage) && message.to_s == "enter"

    @input, command = @input.update(message)
    [self, command]
  end

  def view = "What's your name?\n\n#{@input.view}\n\n(enter to finish)"
end

Bubbletea.run(Prompt.new)
```

bubbles itself is still installed as a gem (`gem install bubbles`); bubbletea and lipgloss don't need to be.

**How conformance is measured.** The upstream gems are the spec. Each case in `conformance/cases/` is a small program or lipgloss call; `bin/conformance record` runs it on the real gems in a pty and saves the decoded screen (text, styles, alt screen, cursor and mouse/paste modes) as a golden, and `bin/conformance check` runs it on r2ui and diffs. Cases listed in `conformance/ratchet/` must keep passing; CI runs `bin/conformance check --ratchet` on every PR and re-records the goldens from the real gems to catch stale ones. Where r2ui differs on purpose, the case is listed in `conformance/concessions/` with the reason (for example, r2ui keeps every key from a multi-key read and delivers long pastes whole, where upstream drops or splits them). See [conformance/README.md](conformance/README.md).

## Contributing and releases

Open PRs against `develop`; `main` holds released code only. Releases and hotfixes are cut from GitHub Actions; see [docs/releasing.md](docs/releasing.md).

## Next: active_tui

A Rails engine on top of the same DSL: `ActiveTui.register Order do ... end` reads columns, scopes and associations from the model, `source` defaults to the relation, and actions become model methods. This gem stays Rails-free.
