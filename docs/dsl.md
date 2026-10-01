# The r2ui DSL on Bubble Tea

Goal: anything a Bubble Tea program can do, an r2ui definition can say, declaratively and in plain
Ruby: custom keys and messages, commands (tick/every, batch, sequence, async work, exec, suspend,
println, window title), alt screen vs inline, mouse, paste, focus, window size, lipgloss styling and
the bubbles components.

This file is the design and the work list. Each capability is one **story**: one new file under
`lib/r2ui/ext/` that registers itself, plus its test. Stories never edit an existing file, so any
number of them can be built at once and merged in any order.

## How a definition runs

`R2UI::App` is a Bubbletea model (`include Bubbletea::Model`), and `R2UI.run` runs it on r2ui's
pure-Ruby Bubbletea engine (`lib/r2ui/compat/bubbletea`, `Bubbletea::Runner`). r2ui has no terminal
loop of its own any more.

| Bubbletea | r2ui |
|---|---|
| `Model.new` | `App.new(registry, name)`: picks the dashboard, builds feeds and panel state, runs extensions' `setup` hooks |
| `init` → `[model, cmd]` | starts the resource feeds, runs the component models' `init` and focuses the focused panel's component, runs extensions' `init` and `after_update` hooks; their commands come back batched. (Component models are built by whichever comes first, the first frame or `init`, so snapshots draw them too.) |
| `update(msg)` → `[model, cmd]` | routes `msg` (below); every command the handlers enqueue comes back batched |
| `view` → String | a `view_override` hook's String if one returns one, else the dashboard drawn into a `Canvas` at the window size (or what `frame_size` hooks make it) |
| Runner options | `App::PROGRAM_OPTIONS` (`alt_screen: true, fps: 20`) merged with every `program_options` hook |
| `WindowSizeMessage` | sets the frame size before anything else sees it |

`update` routes each message in this order:

1. `WindowSizeMessage` updates the size.
2. Every matching `observe` hook runs (never consumes).
3. ctrl+c quits. While the core search (`/`) or confirm (`y/n`) prompt is open, keys go to it.
4. Non-key messages go to every hosted component (`component`), e.g. spinner ticks.
5. `on` handlers with `priority` >= 50, highest first, then load order. The first that matches and
   doesn't `pass` consumes the message.
6. Keys go to the focused component, except tab, shift+tab and ctrl+c. When panel focus changes,
   the panel's first focusable component gets key focus; `focus_component(nil)` takes it away (the
   panel stays focused, keys go on to the next steps).
7. The other `on` handlers (priority < 50; ordinary bindings are 0), the same way.
8. Keys left over go to the core: tab/shift+tab focus, `z` zoom, `q` quit, table keys, actions.

Key names: handlers see the `Bubbletea::KeyMessage`; `R2UI::Keys.name(msg)` gives the core's name
(typed text as a String: `"q"`, `" "`, a whole paste; named keys as Symbols: `:up`, `:page_down`,
`:enter`, `:escape`, `:back_tab`, `:interrupt`, `:"ctrl+r"`, `:f1`). `App#press` takes either form,
so tests drive an app with `app.press("/", "c", :enter)` or `app.press("ctrl+r")`.

Resource feeds still fetch in their own threads; the runner redraws at `fps` and `view` reads the
latest rows. Panels can have no resource (`panel :clock, resource: nil do ... end`) and then hold
only extension items.

## The extension point

`R2UI.extension(name) { ... }` (`lib/r2ui/extension.rb`). Files in `lib/r2ui/ext/*.rb` load
automatically, in name order, from `lib/r2ui.rb`.

| In the block | What it does |
|---|---|
| `dsl(:dashboard \| :row \| :panel \| :resource) { def kw(...) ... end }` | Adds DSL keywords to a builder. Inside, `declare(key, value)` records plain data on the dashboard/resource (`dashboard.declared(key)`); `item(value)` adds a panel item. A keyword that already exists raises, so two stories can't silently take the same name |
| `helpers { def h(...) ... end }` | Methods for every hook and user block (they run on an `R2UI::Context`) |
| `setup { }` | In `App.new`, before any frame: seed state |
| `init { }` | In `App#init`: start timers, fetches |
| `on(matcher, priority: 0) { \|msg\| }` | Handles messages `matcher === msg` (a class, a lambda, ...); consumes unless it calls `pass` |
| `observe(matcher = nil) { \|msg\| }` | Sees messages first, never consumes |
| `after_update { }` | Runs after init and after every update, on that update's Context (its commands go out with it): react to state that changed |
| `panel_item(Klass) { \|item\| String }` | Draws an item; `width`, `height`, `panel` give its space; ANSI kept |
| `component(Klass, focusable: false) { \|item\| model }` | Hosts a Bubbletea-style model (`update` → `[model, cmd]`, `view`) per item: built at init, fed messages, focused with its panel, drawn with `view` (see `lib/r2ui/component.rb`) |
| `hints { [[key, label], ...] }` | Status-bar hints, before the core's (`app.hint_pairs` has them all) |
| `status { String or nil }` | Left status text when the core shows no prompt or flash |
| `program_options { Hash }` | Runner options: `alt_screen`, `mouse_cell_motion`, `mouse_all_motion`, `bracketed_paste`, `report_focus`, `fps` |
| `frame_size { \|w, h\| [w, h] }` | The size the dashboard draws at |
| `view_override { String or nil }` | Replaces the whole view |
| `styles { { style => "SGR" } }` | Canvas palette (`:title`, `:border`, `:focus`, `:selected`, `:accent`, ...) |

The `Context` every block runs on: `app`, `message`, `state` (the app's user Hash), `store(name)`
(an extension's private Hash), `dashboard`, `focus`, `selected_rows`, `component(name)` (a hosted
model), `focus_component(name or nil)` (key focus within the focused panel), `flash`,
`quit`, `command(cmd)` (enqueue any Bubbletea command or a Proc; returns it), `call(block, *args)`
(run a user block here; a returned command is enqueued), `pass`. A block may also just return a
command. App helpers for extensions: `app.panel_state(panel)`, `app.panel_lines(panel)`,
`app.panel_rects` (where each panel was drawn last frame), `app.focus=`, `app.hint_pairs`,
`app.program_options`, `app.width/height`.

Messages an extension sends itself subclass `Bubbletea::Message` (the runner delivers only those
from background commands) and live in its namespace, `R2UI::Ext::<Name>`.

**The reference parts.** `lib/r2ui/ext/every.rb` (keyword + `init` + `on` + own message) with
`test/ext/every_test.rb`, and `lib/r2ui/ext/view.rb` (panel keyword + `panel_item`) with
`test/ext/view_test.rb`. Copy their shape.

## Rules for story work

- Add only the files your story lists: `lib/r2ui/ext/<file>.rb`, `test/ext/<file>_test.rb`, and
  optionally `examples/dsl/<file>.rb`. Edit no existing file. If the core is missing something,
  stop and ask for a contract change instead of editing it.
- Use only the keywords and helpers the story table gives you; they are reserved for you, and
  nobody else uses them. Anything else you add is private (inside `R2UI::Ext::<Name>`).
- The file's header comment is the user documentation: what the keyword does, with an example.
- Tests drive the app through `init` / `update` / `view` / `press` / `frame` like
  `test/ext/every_test.rb`; no real terminal unless the story is about terminal bytes (then a pty
  test via `test/compat/bubbletea/pty_helper.rb`, like `test/engine_test.rb`).
- Component stories call `R2UI::Component.require_bubbles!` when the keyword is first used, never
  at file load (bubbles is optional for apps; the test bundle has it). It opts into
  `r2ui/drop_in` so bubbles runs on r2ui's engine; plain `require "r2ui"` loads the engine by
  path and leaves `require "bubbletea"` alone. Behavior comes from bubbles itself; don't
  reimplement it.
- Priorities: 100 = something capturing all keys (an open modal), 50 = keys a focused thing
  handles itself (beats ordinary bindings, like the focused component does), 0 = ordinary
  bindings, -100 = fallbacks.

## Proposed DSL, by capability

```ruby
R2UI.dashboard do
  title "Deploys"
  state count: 0, log: []                                   # s05

  on_key "r", help: "refresh" do refresh end                # s03, s19
  on_key "ctrl+e", help: "edit" do
    execute(ENV.fetch("EDITOR", "vi"), "notes.md") { |status| flash "editor: #{status.exitstatus}" }  # s09
  end
  on :deployed do |payload| state[:log] << payload end      # s04
  every 5 do emit :poll end                                 # s01, s04
  window_title { "#{state[:count]} deploys" }               # s12
  mouse :cell                                               # s14
  paste                                                     # s15
  report_focus                                              # s16
  on_resize { |w, h| state[:narrow] = w < 100 }             # s17
  min_size 80, 20                                           # s17
  theme do                                                  # s18
    title foreground: "#7D56F4", bold: true
    focus foreground: "#04B575"
  end

  row height: 3 do
    panel :search, resource: nil do
      text_input :query, placeholder: "filter…", on_submit: ->(v) { state[:q] = v }   # s20
    end
    panel :status, resource: nil do
      spinner :busy, style: :dot, label: "deploying", while: -> { state[:busy] }      # s25
      progress(:upload) { state[:sent].to_f / state[:size] }                          # s26
    end
  end
  row do
    panel :deploys do table end
    panel :log, resource: nil do viewport(:log) { state[:log].join("\n") } end        # s24
  end
  row(height: 1) { panel(:keys, resource: nil) { help } }                             # s28
end
```

Inline programs (s13) say `inline height: 8`; a program that draws everything itself (s32) says
`screen { |width, height| "..." }` and has no rows.

## Story list

Done here (first articles): **s01-every**, **s02-view**. Everything else is open. "Adds" are the
names the story owns: keywords on a builder (`dashboard`, `panel`, ...) and Context helpers.

| Id | Capability | Adds | Acceptance criteria | New files |
|---|---|---|---|---|
| s01-every | Repeating timers (tick loop) | dashboard `every` | Done. `every(seconds) { }` runs its block on the update thread every `seconds` from init until quit; a command it returns or enqueues runs; ticks of another app instance are ignored; non-positive intervals and missing blocks raise. | `lib/r2ui/ext/every.rb`, `test/ext/every_test.rb` |
| s02-view | Custom panel content (a model's `view`) | panel `view` | Done. `view { String }` draws its lines (ANSI kept, clipped to the panel) with `width`/`height` of the space left; works in panels with or without a resource, under core items. | `lib/r2ui/ext/view.rb`, `test/ext/view_test.rb` |
| s03-keys | Custom key bindings | dashboard `on_key` | `on_key(*keys, help: nil) { }` binds core or Bubbletea key names (`"r"`, `"ctrl+r"`, `:f1`, `"enter"`); the block runs on a Context and its commands run; bindings beat core keys (binding `"s"` stops the sort key) but not the search/confirm prompts or a focused component; `help:` adds a status-bar hint; binding the same key twice in one dashboard raises. | `lib/r2ui/ext/keys.rb`, `test/ext/keys_test.rb` |
| s04-messages | Custom messages | dashboard `on`; helper `emit` | `on(SomeMessageClass) { \|msg\| }` handles your own `Bubbletea::Message` subclasses; `on(:name) { \|payload\| }` handles `emit(:name, payload, delay: 0)` events (`delay:` uses `Bubbletea.send_message`). Handlers' commands run; unknown events are ignored; a message from a background Proc command reaches its handler. | `lib/r2ui/ext/messages.rb`, `test/ext/messages_test.rb` |
| s05-state | Declared initial state | dashboard `state` | `state count: 0, log: []` seeds `state` in `setup`, so snapshots and the first frame see it; values are deep-copied per app (two apps don't share the array); calling `state` twice merges. | `lib/r2ui/ext/state.rb`, `test/ext/state_test.rb` |
| s06-after | One-shot delay | helper `after` | `after(seconds) { }` runs the block once on the update thread after `seconds` (a `Bubbletea.tick`), with its commands; usable from any block (a key binding, a timer); a later `after` doesn't cancel an earlier one; returns the command. | `lib/r2ui/ext/after.rb`, `test/ext/after_test.rb` |
| s07-batch-sequence | Command composition | helpers `batch`, `sequence` | `batch { a; b }` groups the commands enqueued inside the block into one `Bubbletea.batch` (run concurrently); `sequence { a; b }` into a `Bubbletea.sequence` (in order, stopping at quit); nesting works; an empty block enqueues nothing; both return the command. | `lib/r2ui/ext/batch_sequence.rb`, `test/ext/batch_sequence_test.rb` |
| s08-async | Background work | helper `async` | `async(-> { slow }) { \|value, error\| }` runs the callable off the update thread (a Proc command) and then the block on the update thread with its value, or `nil` and the exception if it raised; the UI keeps drawing meanwhile; results from an app that has quit are dropped. | `lib/r2ui/ext/async.rb`, `test/ext/async_test.rb` |
| s09-exec | Run an external program | helper `execute` | `execute(*argv) { \|status\| }` releases the terminal (leaves alt screen if in it, cooked mode, cursor shown), runs the program in the foreground, restores the terminal, then runs the block with its `Process::Status`. A pty test shows the child's output and the app redrawn after. | `lib/r2ui/ext/exec.rb`, `test/ext/exec_test.rb` |
| s10-suspend | ctrl+z suspend / resume | dashboard `suspendable`, `on_resume`; helper `suspend` | `suspendable` binds ctrl+z to `suspend` (Bubbletea's `SuspendCommand`); `on_resume { }` runs on `ResumeMessage`; the terminal is restored while stopped and set up again after (pty test with SIGTSTP/SIGCONT). | `lib/r2ui/ext/suspend.rb`, `test/ext/suspend_test.rb` |
| s11-println | Print above the program | helper `println` | `println(text)` enqueues Bubbletea's `PutsCommand`, so in inline mode the line appears above the program and stays in the scrollback; returns the command. | `lib/r2ui/ext/println.rb`, `test/ext/println_test.rb` |
| s12-window-title | Window title | dashboard `window_title`; helper `set_window_title` | `window_title "Agents"` or `window_title { dynamic }` sets the title at init and (block form, via `after_update`) again whenever its value changes after an update; `set_window_title(text)` sets it now. Bytes match Bubbletea's (OSC 2). | `lib/r2ui/ext/window_title.rb`, `test/ext/window_title_test.rb` |
| s13-screen-mode | Alt screen vs inline | dashboard `inline`; helpers `enter_alt_screen`, `exit_alt_screen` | `inline height: 10` runs without the alt screen (`program_options`) and draws `height` lines (`frame_size`), leaving the last frame in the scrollback on quit; the helpers switch at runtime; pty test checks the bytes. | `lib/r2ui/ext/screen_mode.rb`, `test/ext/screen_mode_test.rb` |
| s14-mouse | Mouse | dashboard `mouse`, `on_click` | `mouse :cell` / `:all` turns on mouse reporting; a left click focuses the panel under it and selects the clicked table row (using `app.panel_rects`, `panel_state`); the wheel moves the selection; `on_click { \|msg, panel\| }` runs for clicks; reporting is turned off on exit. | `lib/r2ui/ext/mouse.rb`, `test/ext/mouse_test.rb` |
| s15-paste | Bracketed paste | dashboard `paste`, `on_paste` | `paste` turns on bracketed paste; a paste reaches the search prompt or a focused component as text (never as one key binding per character); otherwise `on_paste { \|text\| }` gets it; pasting is turned off on exit. | `lib/r2ui/ext/paste.rb`, `test/ext/paste_test.rb` |
| s16-focus-report | Terminal focus in/out | dashboard `report_focus`, `on_focus`, `on_blur` | `report_focus` enables focus reporting; `on_focus { }` / `on_blur { }` run on `FocusMessage` / `BlurMessage`; `state[:terminal_focused]` tracks it (true at start). | `lib/r2ui/ext/focus_report.rb`, `test/ext/focus_report_test.rb` |
| s17-resize | Window size | dashboard `on_resize`, `min_size` | `on_resize { \|w, h\| }` runs on every `WindowSizeMessage` (the first included); `min_size 80, 20` shows a centered "terminal too small (WxH, need 80x20)" view instead of the dashboard below that size (`view_override`). | `lib/r2ui/ext/resize.rb`, `test/ext/resize_test.rb` |
| s18-theme | Lipgloss styling | dashboard `theme`; helper `style` | `theme { title foreground: "#7D56F4", bold: true; ... }` restyles the canvas styles (`styles` hook) from lipgloss options (colours, bold, italic, underline, reverse, background); `style(**opts)` returns a `Lipgloss::Style` for use in `view` blocks. Colour output matches lipgloss for the same options. | `lib/r2ui/ext/theme.rb`, `test/ext/theme_test.rb` |
| s19-refresh | Refresh a resource now | helper `refresh` | `refresh` (focused panel's resource) or `refresh(:process)` fetches now in a background command instead of waiting for the interval; the next frame shows the new rows; an unknown resource raises. | `lib/r2ui/ext/refresh.rb`, `test/ext/refresh_test.rb` |
| s20-text-input | bubbles TextInput | panel `text_input`; helper `input_value` | `text_input :name, placeholder:, prompt:, width:, char_limit:, on_submit:` hosts a `Bubbles::TextInput` (focusable); typing goes to it while its panel has focus, enter calls `on_submit` with the value, esc blurs (`focus_component(nil)`: keys go back to the core) and enter on its panel again refocuses; `input_value(:name)` reads it. View matches bubbles'. | `lib/r2ui/ext/text_input.rb`, `test/ext/text_input_test.rb` |
| s21-text-area | bubbles TextArea | panel `text_area`; helper `area_value` | `text_area :name, placeholder:, height:` hosts a `Bubbles::TextArea` sized to the panel; enter adds lines; esc blurs; `area_value(:name)` reads it. | `lib/r2ui/ext/text_area.rb`, `test/ext/text_area_test.rb` |
| s22-list | bubbles List | panel `list` | `list :name, items: -> { }, title:, filter: true, on_select: ->(item) { }` hosts a `Bubbles::List` sized to the panel; items refresh each frame from the lambda (or a resource's rows with `resource:`); enter calls `on_select`; filtering with `/` works inside it. | `lib/r2ui/ext/list.rb`, `test/ext/list_test.rb` |
| s23-data-table | bubbles Table | panel `data_table` | `data_table :name, columns: [[title, width], ...], rows: -> { }, on_select:` hosts a `Bubbles::Table` sized to the panel; arrow keys move while focused; enter calls `on_select` with the row. | `lib/r2ui/ext/data_table.rb`, `test/ext/data_table_test.rb` |
| s24-viewport | bubbles Viewport | panel `viewport` | `viewport(:name) { text }` hosts a `Bubbles::Viewport` sized to the panel showing the block's text (re-read each frame, keeping the scroll position); up/down/pgup/pgdown/mouse wheel scroll it while focused; `follow: true` sticks to the bottom as text grows. | `lib/r2ui/ext/viewport.rb`, `test/ext/viewport_test.rb` |
| s25-spinner | bubbles Spinner | panel `spinner` | `spinner :name, style: :dot, label:, while: -> { }` hosts a `Bubbles::Spinner` (any of its spinner styles); it animates from init on its own ticks; with `while:` it shows only while the lambda is true. | `lib/r2ui/ext/spinner.rb`, `test/ext/spinner_test.rb` |
| s26-progress | bubbles Progress | panel `progress` | `progress(:name, width:, gradient:) { fraction }` or `progress :done, of: :total` (resource attributes) hosts a `Bubbles::Progress` sized to the panel showing the fraction (animated with `animate: true`). | `lib/r2ui/ext/progress.rb`, `test/ext/progress_test.rb` |
| s27-paginator | bubbles Paginator | panel `paginate` | `paginate(:name, items: -> { }, per_page: 10) { \|item\| line }` shows one page of lines plus a `Bubbles::Paginator` (dots or `type: :arabic`); left/right/h/l change page while focused. | `lib/r2ui/ext/paginator.rb`, `test/ext/paginator_test.rb` |
| s28-help | bubbles Help | panel `help` | `help` draws `Bubbles::Help` short help from `app.hint_pairs` (core and extension hints); `?` toggles full help; it fits the panel width. | `lib/r2ui/ext/help.rb`, `test/ext/help_test.rb` |
| s29-timer | bubbles Timer (countdown) | panel `countdown` | `countdown :name, seconds, on_timeout: -> { }` hosts a `Bubbles::Timer` that starts at init, shows the time left and calls `on_timeout` once when it ends. | `lib/r2ui/ext/countdown.rb`, `test/ext/countdown_test.rb` |
| s30-stopwatch | bubbles Stopwatch | panel `stopwatch` | `stopwatch :name, autostart: true` hosts a `Bubbles::Stopwatch`; while focused `s` starts/stops and `r` resets. | `lib/r2ui/ext/stopwatch.rb`, `test/ext/stopwatch_test.rb` |
| s31-file-picker | bubbles FilePicker | panel `file_picker` | `file_picker :name, dir: ".", allowed: %w[.rb], on_select: ->(path) { }` hosts a `Bubbles::FilePicker` sized to the panel; navigating and selecting work while focused; `on_select` gets the chosen path. | `lib/r2ui/ext/file_picker.rb`, `test/ext/file_picker_test.rb` |
| s32-screen | A program that draws itself | dashboard `screen` | `screen { \|width, height\| String }` on a dashboard with no rows makes the whole view the block's string (`view_override`), so a plain Bubble Tea-style program (counter, form) needs no panels; keys still reach `on_key` / `on` handlers; `q` and ctrl+c quit. | `lib/r2ui/ext/screen.rb`, `test/ext/screen_test.rb` |

Every story may also add `examples/dsl/<file>.rb`, a runnable example (`exe/r2ui examples/dsl/<file>.rb`).

## Follow-ups (not stories yet)

- Column-level styling (colour a cell by value) needs a `style:` on `column`, which means editing
  `dsl/column.rb` and `widgets/table.rb`: a contract change, not a story.
- Borderless panels (`panel border: false`) are a `Widgets::Box` change; `Panel#options` already
  carries the option for when it lands.
- Several focusable components in one panel (focus moves between them) would extend
  `R2UI::Component`.
