# Paneful

ActiveAdmin-style DSL for terminal dashboards. You declare resources, scopes, groupings, columns and actions; Paneful draws the tables, gauges and sparklines, and handles keys, search, sorting and folding.

Pure Ruby, no runtime dependencies.

```ruby
Paneful.resource :process do
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

Paneful.dashboard do
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
exe/paneful examples/agents.rb              # interactive
exe/paneful --snapshot examples/agents.rb   # print one frame and exit
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

## Next: active_tui

A Rails engine on top of the same DSL: `ActiveTui.register Order do ... end` reads columns, scopes and associations from the model, `source` defaults to the relation, and actions become model methods. This gem stays Rails-free.
