# r2ui for command-line tools

Goal: build a CLI tool in Ruby as fast as you'd build a dashboard with r2ui, and have it look as
good as npm, pnpm or bun on a terminal: spinners that resolve to ✔/✖ lines, task lists with live
status and timings, progress bars with an ETA, styled log levels, boxed notices, trees, aligned
summaries, diffs, prompts. Everything is inline (no alt screen), redrawn in place on a terminal,
and plain, stable lines in a pipe or CI.

This is a second product line next to the dashboard DSL and the Bubble Tea drop-in, not a
replacement. It shares their engine (`lib/r2ui/compat/bubbletea`), their styling (`Lipgloss`) and
the bubbles components, and a command can open a dashboard (c25). Nothing on the TUI side changes.

Like `docs/dsl.md`, this file is the design and the work list. Each capability is one **story**:
one new file under `lib/r2ui/cli/ext/` that registers itself, plus its test. Stories never edit an
existing file, so any number of them can be built at once and merged in any order.

## A tool

```ruby
#!/usr/bin/env ruby
require "r2ui/cli"

R2UI.cli "deployer" do
  summary "Ship apps to the fleet"
  flag :verbose, short: "v", desc: "Show more"            # on the root: every command has it

  command :deploy do
    summary "Deploy an app"
    aliases :d
    argument :app, desc: "App to deploy"
    argument :sha, required: false, desc: "Commit (default: HEAD)"
    option :env, short: "e", default: "staging", in: %w[staging production], desc: "Target"
    option :replicas, :integer, default: 2
    flag :force, short: "f", desc: "Skip the checks"

    run do
      if options[:env] == "production" && !options[:force]
        confirm("Deploy #{args[:app]} to production?") or abort!("cancelled", code: 1)
      end
      tasks do
        step("Building") { build(args[:app], args[:sha]) }
        step("Uploading") { |s| upload { |pct| s.detail = "#{pct}%" } }
        step("Migrating") { |s| s.skip!("no migrations") unless pending_migrations? }
        step("Restarting #{options[:replicas]} replicas") { restart }
      end
      say "Deployed #{args[:app]} to #{options[:env]}", :success
    end
  end

  command :db do
    summary "Database tasks"
    command(:migrate, "Run pending migrations") { run { step("Migrating") { migrate } } }
  end
end.start
```

A runnable version is `examples/cli/deployer.rb`. On a terminal `deployer deploy api -e production`
asks, then draws

```
✔ Deploy api to production? · Yes
✔ Building 1.2s
⠹ Uploading · 64%
○ Migrating
○ Restarting 2 replicas
```

redrawn in place until every step resolves. Piped (`deployer deploy api | cat`, CI) the same run
prints only stable lines, one per finished step, without escape codes:

```
✔ Building 1.2s
✔ Uploading · 100% 3.4s
– Migrating (no migrations)
✔ Restarting 2 replicas 0.8s
Deployed api to staging
```

## The commands DSL

`R2UI.cli(name) { ... }` (or `R2UI::CLI.define`) builds a `Program` (the root `Command`) from the
block, the way `R2UI.dashboard` builds a dashboard: definitions are plain data; nothing in them
parses or prints. `Program#start(argv = ARGV)` runs and exits with the code; `Program#call(argv,
shell:)` returns the code (tests). `R2UI::CLI.start` runs the last one defined.

| Keyword | Meaning |
|---|---|
| `summary "..."` / `description "..."` | One line for command lists; longer text for its help |
| `command :name, "summary" do ... end` | A subcommand; nests (`db migrate`). `hidden: true` leaves it out of help |
| `aliases :d, :ship` | Other names the command answers to |
| `argument :name, type = :string, required: true, many: false, default:, desc:` | Positionals, in order. `default:` makes it optional; `many:` (last only) takes the rest as an Array |
| `option :name, type = :string, short:, default:, required:, in:, many:, placeholder:, desc:, hidden:, **meta` | `--name value`, `--name=value`, `-n value`, `-nvalue`. `in:` limits values; `many:` collects repeats; `default:` may be a lambda (called only when not given); `meta` keeps other keywords for extensions |
| `flag :name, short:, default: false, desc:` | A boolean option: `--name`, `--no-name`, clustered `-vf`; help shows `--[no-]name` for default-true flags |
| `run { ... }` | What the command does; the block runs on a `Context` |

Types: `:string`, `:integer`, `:float`, `:boolean`, `:path` (expanded), or anything with `#call`
(`->(s) { URI(s) }`). An option on a group applies to every command under it (cobra's persistent
flags, Thor's class options); an option comes anywhere after the command that owns it; `--` ends
options.

In `run` (a `Context`, `lib/r2ui/cli/context.rb`): `args[:app]`, `options[:env]`,
`given?(:env)`, `argv`, `command`, `program`, `shell`, every helper, and the ways out:
`abort!("msg", code: 1)`, `halt(code)`, `usage_error!("msg")`.

**Help** is generated (`lib/r2ui/cli/help.rb`): `deployer --help`, `-h`, `deployer help deploy`,
`deployer deploy --help`; a group run without a subcommand prints its help. Sections: the
description, Usage, Arguments, Commands, Options (with choices, defaults, `required`), then any
extension's `help_section`. Headings bold and names in the accent colour on a terminal; plain
text in a pipe.

**Exit codes** (`lib/r2ui/cli/runner.rb`): 0 success (and help); 1 an error (`CLI::Error`,
`abort!`, any exception: "✖ message" on stderr; `R2UI_TRACE=1` adds the backtrace); 2 a usage
error (unknown/missing/bad command, option or argument, with "Did you mean 'deploy'?" and a
"Run 'deployer deploy --help' for usage." hint); 130 ctrl+c; `abort!(code:)`/`halt(n)` choose. A
closed stdout (`deployer status | head -1`) ends quietly with 0.

**How a command runs:** parse argv → `after_parse` hooks (fill options from env, config) →
defaults and required checks → `before_run` hooks → the `run` block → `after_run` hooks. An
escaping error goes to the `on_error` hooks, then the core's report.

## Inline helpers

Helpers are methods on `R2UI::CLI::Helpers`: available in every `run` block, in any script that
does `include R2UI::CLI::Helpers`, and as `R2UI::CLI.confirm(...)`. They write only through a
`Shell` (`lib/r2ui/cli/shell.rb`), never to `$stdout` directly. Core gives `say(text, *styles)`;
the rest are stories.

```ruby
require "r2ui/cli"
include R2UI::CLI::Helpers

name = ask("Project name?", default: "app")                       # c17
exit 1 unless confirm("Create #{name}?")                           # c03
tasks do                                                           # c02
  step("Scaffolding") { scaffold(name) }
  step("Installing") { |s| install { |n, total| s.detail = "#{n}/#{total}" } }
end
box "Created #{name}\n\n  cd #{name}\n  bin/dev", title: "Next steps"   # c07
```

### On and off a terminal

The `Shell` decides, once, from its IOs and the environment:

| Shell | True when | Used for |
|---|---|---|
| `live?` | stdout is a terminal and `TERM` isn't `dumb` | redrawing in place (spinners, task lists, progress) |
| `interactive?` | stdin and stdout are terminals | inline prompts that take keys |
| `input_tty?` | stdin is a terminal | asking a line on stderr when stdout is piped |
| `color?` | `NO_COLOR` unset, and `FORCE_COLOR` set or `live?` | styling text |

| Helper kind | On a terminal | Off a terminal (pipe, CI, `TERM=dumb`) |
|---|---|---|
| Live output (tasks, spin, progress, parallel) | redrawn in place at 12 fps; cursor hidden while drawing and shown on every exit path; the final frame stays in the scrollback; `say` inside prints above the region | nothing while running; one line per event when it ends (`✔ Building 1.2s`); never a spinner frame or escape code |
| Static output (say, log levels, box, tree, table, pairs, diff) | styled with the theme | the same text and layout, no colour (tables drop their borders: plain aligned columns) |
| Prompts (confirm, ask, choose, ...) | an inline Bubbletea program: raw mode while asking, the answered line ("✔ Name? · app") left behind, ctrl+c → exit 130 | read one line: asked on stderr if stdin is a terminal, silently from a pipe (`yes \| tool`, `echo app \| tool`); end of input → the `default:`; no default → a clear error naming the question |
| Pager | `$PAGER` (`less -R -F -X`) when taller than the screen | printed |

Errors and warnings go to stderr; data goes to stdout, so `tool | jq` stays clean.

### How it reuses r2ui

- **Engine.** `Live` (`lib/r2ui/cli/live.rb`) draws with `R2UI::Compat::Tea::Renderer`, Bubbletea's
  inline renderer, so in-place redraw and erasing behave exactly like an inline Bubbletea
  program's; it takes no raw mode, so the work runs on the caller's thread and ctrl+c is an
  ordinary `Interrupt`. Prompts (`lib/r2ui/cli/prompt.rb`) are Bubbletea models run by
  `Bubbletea::Runner` inline (`Prompt::InlineRunner`, on the shell's IOs).
- **Components.** Prompt stories host bubbles models inside their `Prompt::Model` (TextInput for
  `ask`/`password`/`filter`) after `R2UI::CLI.require_bubbles!`, which opts into `r2ui/drop_in`.
  Bubbles stays optional: only prompts that need it load it. The spinner frames are bubbles'
  `MINI_DOT`.
- **Styling.** `Theme` maps names (`:success`, `:error`, `:warn`, `:info`, `:accent`, `:highlight`,
  `:muted`, `:heading`, ...) to lipgloss options (the vocabulary of the dashboard's s18 `theme`)
  and renders with `Lipgloss::Style`; boxes, tables and trees are `Lipgloss` borders, `Table` and
  `Tree`. Colours are ANSI palette numbers so they follow the user's terminal theme.
- **Dashboards.** `require "r2ui/cli"` loads the engine and Lipgloss, not the dashboard DSL (a CLI
  starts fast). The c25 `dashboard` helper loads it when a command opens one.

## The extension point

`R2UI::CLI.extension(name) { ... }` (`lib/r2ui/cli/extension.rb`), the same shape as
`R2UI.extension`. Files in `lib/r2ui/cli/ext/*.rb` load automatically, in name order, from
`lib/r2ui/cli.rb`.

| In the block | What it does |
|---|---|
| `dsl(:command) { def kw(...) ... end }` | Adds keywords to the command `Builder` (root and subcommands). Inside, `definition` is the `Command`, `declare(key, value)` records plain data on it (`command.declared(key)`). A keyword that already exists raises |
| `helpers { def h(...) ... end }` | Adds helpers (to `Helpers`, so to every `Context`, to scripts and to `R2UI::CLI`). A name that exists raises (Kernel's private ones, like `warn`, may be replaced) |
| `setup { }` | Runs on the root's `Builder` after the `R2UI.cli` block: add options or commands the tool asked for |
| `after_parse { }` | On the Context after argv is parsed, before defaults and required checks: `options[:x] = ... unless given?(:x)` |
| `before_run { }` / `after_run { }` | On the Context around the `run` block; `halt` ends early |
| `help_section { \|command, shell\| [heading, lines] }` | Appends a section to `--help` (nil for none) |
| `on_error(Klass) { \|error\| }` | On the Context when an error escapes; return an Integer to make it the exit code and skip the core's report |

Building blocks for stories: `Shell` (`puts`, `err_puts`, `paint`, `symbol`, `width`, `live?`,
`interactive?`, `input_tty?`), `Theme`, `Live` (`run`, `refresh`, `println`, `Live.spinner`),
`Prompt.run(shell, model)`, `Prompt::Model` (`key(name, msg)`, `submit(value)`, `view`),
`Prompt.read_line(shell, prompt)`. A story's private classes live in `R2UI::CLI::Ext::<Name>`.

**The reference parts.** `lib/r2ui/cli/ext/tasks.rb` (output: a `Live` region on a terminal, one
plain line per event off it) with `test/cli/ext/tasks_test.rb`, and `lib/r2ui/cli/ext/confirm.rb`
(prompt: a `Prompt::Model` inline, a line-reading fallback) with `test/cli/ext/confirm_test.rb`.
Copy their shape.

## Rules for story work

- Add only the files your story lists: `lib/r2ui/cli/ext/<file>.rb`, `test/cli/ext/<file>_test.rb`,
  and optionally `examples/cli/<file>.rb`. Edit no existing file (not the core, not another
  story's, not `lib/r2ui/ext/`). If the core is missing something, stop and ask for a contract
  change.
- Use only the keywords and helpers the story table gives you; they are reserved for you. Anything
  else is private (inside `R2UI::CLI::Ext::<Name>`). Don't depend on another story's file: they
  are built at the same time.
- The file's header comment is the user documentation: what it does on and off a terminal, with
  an example.
- Write through the `Shell`; draw live output with `Live`; run prompts with `Prompt.run`. Every
  terminal mode you turn on is turned off on every exit path (return, exception, ctrl+c).
- Off a terminal: no escape codes, no animation, one stable line per event; nothing waits for
  keys that can't come.
- Tests use `R2UI::CLI::Testing` (`run_cli`, `with_shell`, `test_shell`): a pipe by default,
  `tty: true` for terminal output (decode it with `Conformance::VT`, as tasks_test does), an
  in-process `PTY.open` for prompts (as confirm_test does). Assert what a user sees, not internals.
- Prompt stories that host bubbles call `R2UI::CLI.require_bubbles!` when first used, never at file
  load. Behaviour comes from bubbles itself; don't reimplement it.

## Story list

Done here (first articles): **c01-commands**, **c02-tasks**, **c03-confirm**. Everything else is
open. "Adds" are the names the story owns: helpers, or keywords on the command builder.

### Done

| Id | Capability | Adds | Acceptance criteria | Files |
|---|---|---|---|---|
| c01-commands | Commands, arguments, typed options, help, exit codes | `R2UI.cli`; keywords `summary`, `description`, `command`, `aliases`, `argument`, `option`, `flag`, `run`, `hidden`; helper `say` | Done. The keyword table, "Help" and "Exit codes" above hold; parse errors are usage errors with "did you mean"; options inherit down groups; help is plain off a terminal. | `lib/r2ui/cli.rb`, `lib/r2ui/cli/{shell,live,definition,builder,parser,help,helpers,context,extension,prompt,runner,testing}.rb`, `test/cli/{parser,help,runner,shell,live}_test.rb` |
| c02-tasks | npm-style task list | helpers `tasks`, `step` | Done. See the file header: pending ○ / spinner / ✔ ✖ – with timings, redrawn in place; one line per finished step off a terminal; failure skips the rest and re-raises; `skip!`, `detail=`; `say` prints above. | `lib/r2ui/cli/ext/tasks.rb`, `test/cli/ext/tasks_test.rb` |
| c03-confirm | Yes/no prompt | helper `confirm` | Done. Inline Yes/No toggle on a terminal leaving "✔ Q · Yes"; ctrl+c/esc → Interrupt; off a terminal y/yes/n/no lines, empty/EOF → default, re-asks a person, errors on a pipe's unreadable answer. | `lib/r2ui/cli/ext/confirm.rb`, `test/cli/ext/confirm_test.rb` |

### Output

| Id | Capability | Adds | Acceptance criteria | New files |
|---|---|---|---|---|
| c04-spinner | One spinner line (ora, gum spin) | helper `spin` | `spin("Installing", done: "Installed") { \|s\| s.text = "..."; work }` shows a spinner and the text on a terminal and resolves to "✔ Installed 1.2s" (`done:` defaults to the title; a lambda gets the block's value) or "✖ Installing" on an exception, which propagates; `clear: true` erases the line on success; returns the block's value; off a terminal prints only the resolved line. | `lib/r2ui/cli/ext/spinner.rb`, `test/cli/ext/spinner_test.rb` |
| c05-progress | Progress bar with rate and ETA | helper `progress` | `progress(total: 10_000_000, title: "Downloading", unit: :bytes) { \|bar\| bar.advance(n) }` (also `bar.current =`, `bar.total =`) draws `Downloading ━━━━━━╸──── 42% 4.2/10 MB · 1.3 MB/s · ETA 4s` on a terminal, sized to the width, with a lipgloss colour blend; `total: nil` shows an indeterminate bar; resolves to "✔ Downloading 10 MB 7.6s"; off a terminal prints "Downloading 25%", 50%, 75% lines and the resolved line; returns the block's value; ✖ and re-raise on an exception. | `lib/r2ui/cli/ext/progress.rb`, `test/cli/ext/progress_test.rb` |
| c06-log | Styled log levels | helpers `info`, `success`, `warn`, `error`, `debug` | Each prints one line `<symbol> message` (ℹ ✔ ⚠ ✖, coloured by level on a terminal; multi-line messages indent under the first); `info`/`success` go to stdout, `warn`/`error` to stderr; `debug` prints (muted, to stderr) only when `options[:verbose]` is true in a command or `R2UI_DEBUG` is set; they replace Kernel#warn inside commands and scripts that include the helpers; inside a Live region they print above it. | `lib/r2ui/cli/ext/log.rb`, `test/cli/ext/log_test.rb` |
| c07-box | Boxed notice ("Update available") | helper `box` | `box(text, title: nil, style: :info, padding: 1, width: nil)` prints a rounded lipgloss border box (border in the style's colour, title in the top border or as its first line), never wider than the shell; off a terminal the same box without colour; multi-line text and wide characters keep the right edge aligned. | `lib/r2ui/cli/ext/box.rb`, `test/cli/ext/box_test.rb` |
| c08-tree | Dependency-style tree | helper `tree` | `tree("app@1.0", { "rails@7.1" => { "rack@3.0" => nil }, "pg@1.5" => nil })` (Hash/Array nesting; leaves as Strings) prints `├──`/`└──`/`│` lines via `Lipgloss::Tree`, root bold and names styled on a terminal, identical glyphs without colour off it; `depth:` truncates with "…". | `lib/r2ui/cli/ext/tree.rb`, `test/cli/ext/tree_test.rb` |
| c09-pairs | Aligned key/value summary | helper `pairs` | `pairs({ "Version" => "1.4.0", "Env" => "production" }, title: "Deploy")` prints keys right-padded to the longest (display width), muted keys and plain values on a terminal, an optional bold title line; nil values show "—"; off a terminal the same alignment, no colour. | `lib/r2ui/cli/ext/pairs.rb`, `test/cli/ext/pairs_test.rb` |
| c10-table | Tables | helper `table` | `table(rows, headers: nil)` (rows as Arrays or Hashes; headers from Hash keys) draws a `Lipgloss::Table` with a rounded border and bold header on a terminal, fit to the width; off a terminal prints plain columns aligned with two spaces and no border (`awk`-friendly); `align: { 2 => :right }` right-aligns columns; empty rows print just the header. | `lib/r2ui/cli/ext/table.rb`, `test/cli/ext/table_test.rb` |
| c11-diff | Unified diff | helper `diff` | `diff(old, new, labels: %w[a b], context: 3)` prints a unified diff (`---`/`+++`, `@@` hunks, a pure-Ruby LCS) with removed lines red, added green, hunks muted on a terminal; same text off it; returns true when they differ and prints nothing when equal. | `lib/r2ui/cli/ext/diff.rb`, `test/cli/ext/diff_test.rb` |
| c12-pager | Pager | helper `pager` | `pager(text)` pipes text through `$PAGER` (default `less -R -F -X`) when the shell is interactive and the text is taller than the screen, waits for it, and restores nothing it didn't change; otherwise prints it; a missing pager program falls back to printing. | `lib/r2ui/cli/ext/pager.rb`, `test/cli/ext/pager_test.rb` |
| c13-parallel | Concurrent jobs with live status (pnpm -r, turbo) | helpers `parallel`, `job` | `parallel(max: 4) { job("api") { build_api }; job("web") { build_web } }` runs jobs on up to `max` threads, one status line each (spinner → ✔/✖ with timing) redrawn together on a terminal; a failing job doesn't stop the others; after all end, raises a `CLI::Error` naming the failed jobs (first error as cause); off a terminal prints one line per job as it ends; returns values by job name. | `lib/r2ui/cli/ext/parallel.rb`, `test/cli/ext/parallel_test.rb` |
| c14-format | Human formats | helpers `duration`, `bytes`, `plural`, `link` | `duration(75.2)` → "1m 15s" (ms under a second), `bytes(1_500_000)` → "1.5 MB", `plural(3, "package")` → "3 packages" (`plural(1, "child", "children")`), `link(url, text)` → an OSC 8 hyperlink when colour is on, "text (url)" otherwise. | `lib/r2ui/cli/ext/format.rb`, `test/cli/ext/format_test.rb` |
| c15-summary | Headers and final summary lines | helpers `heading`, `done` | `heading("deployer v1.4.0")` prints a bold line (and a blank line after); `done("Deployed 3 apps")` prints "✔ Deployed 3 apps in 4.2s", timed from the start of the command (or the first helper call in a script), like npm's "added 42 packages in 3s"; `done(nil)` prints "Done in 4.2s". | `lib/r2ui/cli/ext/summary.rb`, `test/cli/ext/summary_test.rb` |
| c16-list | Bullet and numbered lists | helper `list` | `list(items, numbered: false)` prints "• item" (or "1. item", numbers right-aligned) lines, wrapped items indented under their text at the shell width, bullets in the accent colour on a terminal; nested Arrays indent a level. | `lib/r2ui/cli/ext/list.rb`, `test/cli/ext/list_test.rb` |

### Prompts

| Id | Capability | Adds | Acceptance criteria | New files |
|---|---|---|---|---|
| c17-ask | Text input | helper `ask` | `ask("Project name?", default: "app", placeholder:, validate: ->(v) { "too short" if v.size < 2 })` hosts a bubbles `TextInput` inline; enter submits (the default when empty); a validation message shows under it until fixed; leaves "✔ Project name? · app"; off a terminal reads a line (validation failures from a pipe are errors, a person is re-asked); end of input with no default raises a `CLI::Error` naming the question and suggesting an option. | `lib/r2ui/cli/ext/ask.rb`, `test/cli/ext/ask_test.rb` |
| c18-password | Hidden input | helper `password` | `password("Token?", confirm: false)` hosts a `TextInput` in password echo mode (•), never prints the value, leaves "✔ Token? · ••••••"; `confirm: true` asks twice and re-asks on mismatch; off a terminal reads a line without echo (`IO#noecho` when stdin is a terminal) and never records the value. | `lib/r2ui/cli/ext/password.rb`, `test/cli/ext/password_test.rb` |
| c19-choose | Pick one | helper `choose` | `choose("Region?", %w[eu us ap], default: "eu")` (or a Hash label ⇒ value) shows a pointer list (↑/↓/j/k, enter; scrolls past 10 items with a "↓ 4 more" hint) and returns the value, leaving "✔ Region? · eu"; off a terminal reads a line: a label or its 1-based number; end of input → default, or an error without one. | `lib/r2ui/cli/ext/choose.rb`, `test/cli/ext/choose_test.rb` |
| c20-choose-many | Pick several | helper `choose_many` | `choose_many("Features?", choices, selected: [...], min: 0, max: nil)` shows a checkbox list (space toggles, a toggles all, enter submits when within min/max) and returns the chosen values in list order; leaves "✔ Features? · a, b"; off a terminal reads a comma-separated line of labels or numbers. | `lib/r2ui/cli/ext/choose_many.rb`, `test/cli/ext/choose_many_test.rb` |
| c21-filter | Type to filter (gum filter) | helper `filter` | `filter("Branch?", branches)` shows a `TextInput` above a list narrowed by fuzzy match as you type (matched characters highlighted), ↑/↓ and enter pick; returns the choice; off a terminal reads a line and returns the best match or raises when nothing matches. | `lib/r2ui/cli/ext/filter.rb`, `test/cli/ext/filter_test.rb` |
| c22-editor | Edit in $EDITOR | helper `edit` | `edit(text = "", ext: ".md")` writes text to a temp file, runs `$VISUAL`/`$EDITOR` (default `vi`) in the foreground and returns the saved contents (temp file removed on every path); off an interactive shell raises a `CLI::Error` ("needs a terminal"). | `lib/r2ui/cli/ext/editor.rb`, `test/cli/ext/editor_test.rb` |

### Commands

| Id | Capability | Adds | Acceptance criteria | New files |
|---|---|---|---|---|
| c23-version | `--version` | keyword `version` | `version "1.4.0"` on the root adds `-V, --version` (setup); `tool --version` prints "deployer 1.4.0" and exits 0 before any validation of required options or arguments; the root's help shows the version on its first line. | `lib/r2ui/cli/ext/version.rb`, `test/cli/ext/version_test.rb` |
| c24-completion | Shell completion scripts | keyword `completion` | `completion` on the root adds a `completion <bash\|zsh\|fish>` command printing a static script that completes commands, aliases, options and `in:` choices from the definition tree; `bash -n`/`zsh -n` accept the scripts when those shells exist; hidden commands and options are left out. | `lib/r2ui/cli/ext/completion.rb`, `test/cli/ext/completion_test.rb` |
| c25-dashboard | A command opens a dashboard | helper `dashboard` | `run { dashboard :fleet, file: "dashboards.rb" }` loads the dashboard DSL (`require "r2ui"`) and the file, runs `R2UI.run(:fleet)` full screen and returns when the user quits, terminal restored; off an interactive shell prints one `R2UI.snapshot` frame at the shell width instead. | `lib/r2ui/cli/ext/dashboard.rb`, `test/cli/ext/dashboard_test.rb` |
| c26-env | Options from environment variables | option meta `env:` | `option :token, env: "DEPLOY_TOKEN"` fills a not-given option from the variable in `after_parse` (converted and validated like typed input; a bad value is a usage error naming the variable), before required checks; command-line values win; an "Environment" help section lists the variables. | `lib/r2ui/cli/ext/env.rb`, `test/cli/ext/env_test.rb` |
| c27-config | Options from a config file | keyword `config_file` | `config_file "~/.deployer.yml"` (YAML or JSON by extension) adds `--config PATH`; top-level keys fill not-given options of every command, a `deploy:` section those of `deploy` (nested by command path); command line and env win; a missing default file is fine, a missing `--config` file or a bad key is a usage error. | `lib/r2ui/cli/ext/config.rb`, `test/cli/ext/config_test.rb` |
| c28-trace | `--trace` | keyword `trace_option` | `trace_option` on the root adds `--trace`; with it, an unexpected error prints "✖ message" then the exception class and full backtrace (muted) and exits 1; without it, unchanged. | `lib/r2ui/cli/ext/trace.rb`, `test/cli/ext/trace_test.rb` |
| c29-examples | Examples in help | keyword `example` | `example "deployer deploy api -e production", "Deploy api to production"` (repeatable, on any command) adds an "Examples" help section: muted comment line, then the command in the accent colour. | `lib/r2ui/cli/ext/examples.rb`, `test/cli/ext/examples_test.rb` |
| c30-reference | Markdown reference | keyword `reference_command` | `reference_command` on the root adds a hidden `reference` command printing Markdown for every visible command (heading by path, summary, usage, argument and option tables), for README or docs sites; stable output for the same definition. | `lib/r2ui/cli/ext/reference.rb`, `test/cli/ext/reference_test.rb` |
| c31-color-option | `--[no-]color` | keyword `color_option` | `color_option` on the root adds `--color`/`--no-color` (setup); `before_run` sets the shell's colour when given, so `--no-color` on a terminal prints no escape codes for colour (live redraw still happens) and `--color` styles output in a pipe. | `lib/r2ui/cli/ext/color_option.rb`, `test/cli/ext/color_option_test.rb` |

Every story may also add `examples/cli/<file>.rb`, a runnable example.

## Follow-ups (not stories yet)

- One theme for both products: the CLI `Theme` and the dashboard's s18 `theme` use the same lipgloss
  options; once s18 lands, a shared `R2UI::Theme` (contract change) lets a tool style both alike.
- `--quiet` needs the Shell to know about verbosity (a core change), so it isn't a story yet.
- Lipgloss picks its colour profile from the process's stdout once, so `FORCE_COLOR` into a pipe
  colours only when lipgloss's own detection agrees (`CLICOLOR_FORCE=1`); a per-render profile would
  be a compat change.
- `Prompt::InlineRunner` points Bubbletea's runner at the shell's IOs by replacing its program;
  upstream's runner has no option for that.
- Subtasks (a step with its own steps) and a default subcommand need core changes.
