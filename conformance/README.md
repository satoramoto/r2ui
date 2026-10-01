# Conformance harness

Measures r2ui's drop-in (`require "r2ui/drop_in"`) against the upstream Charm gems (bubbletea 0.1.4, lipgloss 0.2.2, bubbles 0.1.1). The upstream gems are the spec: a case's golden output is whatever they produce, recorded by a script and never edited by hand.

```
bin/conformance record [filter...]             # run cases on the real gems, (re)write goldens
bin/conformance check [filter...]              # run cases on r2ui, diff against goldens; fails on any failure (conceded cases excepted)
bin/conformance check --ratchet [filter...]    # fails only if a case listed in conformance/ratchet/ fails
bin/conformance list [filter...]               # list case ids
```

Filters match case ids by substring (`bin/conformance check lipgloss/border`). `-j N` sets how many cases run at once (default: CPU count). Pass/fail is the exit code. Recording needs the upstream gems installed (`gem install bubbletea:0.1.4 lipgloss:0.2.2 bubbles:0.1.1 harmonica:0.1.1`); checking needs bubbles/harmonica for cases that use them.

## Layout

| Path | What |
|---|---|
| `cases/<area>/.../<name>.rb` | One case. Its id is the path without `cases/` and `.rb`, e.g. `lipgloss/border/rounded_padded_box`; its area is the first directory |
| `golden/<id>.txt` | Recorded output for each case. Written only by `bin/conformance record` |
| `ratchet/<area>.txt` | Case ids that must pass, one per line (`#` comments). Starts empty |
| `concessions/<area>.txt` | Case ids where r2ui differs from upstream on purpose, `<id>  # reason` per line. See [Concessions](#concessions) |
| `lib/` | The harness: `harness.rb` (cases, goldens, ratchet), `pty_runner.rb` (pty + input), `vt.rb` (terminal decoder), `child.rb` (runs one case in the pty) |

## Writing a case

Add one `.rb` file under `cases/`, run `bin/conformance record <id>`, look at the golden, commit both. A case is plain Ruby that requires the gems it uses (`require "lipgloss"`, `require "bubbletea"`, `require "bubbles"`); under `check` those requires resolve to r2ui. Optional YAML after `__END__` configures it.

### Value cases (lipgloss and other pure functions)

The file's last expression is a String; that string, byte for byte, is the result. No `__END__` section (or one without `steps:`).

```ruby
# Bold, true-colour foreground on a single word.
require "lipgloss"

Lipgloss::Style.new.bold(true).foreground("#FF8700").render("Hello")
```

The golden holds the string one output line per line, `inspect`-escaped so escape codes are visible:

```
"\e[1;38;2;255;135;0mHello\e[0m"
```

Strings are compared exactly, so the SGR sequences r2ui emits must match the gem's.

### Program cases (bubbletea, bubbles)

The file runs a program; the YAML after `__END__` has `steps:` (and optionally `size:`, default `80x24`, and `quiet:`). The program runs in a pty of that size; each step sends input, waits until output goes idle, and may snapshot the screen.

```ruby
require "bubbletea"
# ... a model ...
Bubbletea.run(Counter.new)

__END__
size: 40x8
steps:
  - snapshot: start              # after startup output goes idle
  - keys: [up, up, k]            # each key sent separately, waiting for idle after each
    snapshot: three
  - keys: [q]
    exit: true                   # optional: wait for the program to exit; the snapshot records the exit status
    snapshot: quit
```

Step keys (all optional, applied in this order):

| Key | Does |
|---|---|
| `resize: 60x10` | Resizes the pty (the program gets SIGWINCH, so bubbletea sends a `WindowSizeMessage`) and the decoded screen, then waits for idle. Later snapshots have the new size |
| `keys: [..]` | Sends each key, waiting for idle after each. Names: `up down left right home end pgup pgdown insert delete enter tab shift+tab esc backspace space ctrl+a`..`ctrl+z`; anything else is sent literally, as **one write** (`q`, `hello`). Upstream bubbletea makes one event from the first character of a read and drops the rest, so `keys: [hello]` is not five key presses: list them, `keys: [h, e, l, l, o]` |
| `input: "..."` | Sends raw bytes in one write (YAML double quotes allow `"\e[A"`), then waits for idle |
| `wait_for: "text"` | Waits until some screen row contains the text, then for idle |
| `exit: true` | Waits for the program to exit and records its exit status in the snapshot. Not required: after the last step the harness kills the program anyway |
| `snapshot: name` | Records the screen under this name. An empty name (`snapshot:` with nothing after it) is an error |

A step that is just a string is a snapshot name.

Quote YAML scalars that YAML would otherwise read as something else: `keys: ["!", "?", "*", "&", "#", "[", "{", ":", "-", "yes", "no", "on", "off", "1"]`. Unquoted, `!` is a tag, `#` starts a comment, `yes` is a boolean and `1` an integer.

Case options (top level of the YAML, besides `steps:`):

| Key | Does |
|---|---|
| `size: 40x8` | Terminal size, default `80x24` |
| `quiet: 0.5` | Seconds of silence that count as idle (default 0.3) |
| `window_title: true` | Each snapshot gets a `title:` line with the last window title set by OSC 0 or OSC 2 (`-` if none). Off by default so goldens without it never change |

**Warnings, not snapshot lines.** A snapshot only shows what is on screen. If non-blank rows scrolled off the top, or a row overflowed the width and wrapped, before a snapshot, `record` prints a `warning:` on stderr naming the case and snapshot. The golden is unchanged; usually the fix is a bigger `size:`.

**The gauge** is the screen, not the bytes: everything the program writes is decoded by `lib/vt.rb` (an xterm-like decoder: cursor movement, erase, scrolling and margins, SGR, alt screen, wide characters) into a grid of cells. A snapshot lists each row's text, then the styled runs, then alt-screen, cursor visibility and tracked modes (mouse, bracketed paste, focus). Two renderers that draw the same screen with different escape codes give the same snapshot. Cursor position is not compared.

```
== start
alt_screen: on  cursor: hidden  modes: -
1| Fruit
...
styles:
1:1-7 bold fg=#fafafa bg=#7d56f4
```

### Keeping goldens stable

Recording runs twice in CI and must give identical goldens, so a snapshot must not depend on timing:

- Snapshot only states the program settles in. "Idle" means no output for `quiet` seconds (default 0.3, `CONFORMANCE_QUIET` overrides), so anything that keeps redrawing (an endless spinner, a clock) never settles. Bound it instead: tick a fixed number of times, then stop (see `cases/bubbletea/tick.rb`).
- Use `wait_for:` to wait on what the screen says rather than on time.
- Don't print times, random values, PIDs or paths.

### Same conditions for recording and checking

Both run each case as `ruby [-I lib -r r2ui/drop_in] conformance/lib/child.rb <case>` under a pty with `TERM=xterm-256color`, `COLORTERM=truecolor`, `LANG=LC_ALL=C.UTF-8`, and no bundler environment. Because stdout is a terminal that advertises true colour, lipgloss renders with its true-colour profile (piped stdout would strip all styling). Value cases also run under the pty for that reason; their result comes back through a file. The decoder answers terminal queries (cursor position, OSC 10/11 colours: white on black, DA1, DECRQM), so a program that asks doesn't stall.

## Ratchet

`ratchet/<area>.txt` lists the cases that must keep passing. When a lane makes a case pass, it adds the id; `check --ratchet` (run in CI on every PR) then fails if that case regresses, and lists cases that pass but aren't listed yet. Listing an id that has no case is also a failure.

## Concessions

A **concession** is the factory's way of accepting a documented nonconforming part: a case where r2ui differs from the upstream gem on purpose, because upstream is wrong in a way no program should depend on. For example, upstream bubbletea makes one event from a multi-byte read and drops the rest, and garbles bracketed paste; r2ui delivers every event and the whole paste.

`concessions/<area>.txt` lists them, one per line, with the reason after `#`:

```
bubbletea/keys/one_write_one_event  # upstream drops all but the first event of a read; r2ui keeps them all
```

- The golden stays what upstream does (it is still recorded, never edited), so the difference stays visible: `bin/conformance check <id>` shows it.
- `check` reports a conceded case that differs from its golden as `CONCEDED <id>  # reason`, not as a failure, and it doesn't change the exit code. A conceded case that errors (crashes, times out, loads an upstream gem) still fails. One that passes is reported as `PASS` with a hint to drop the concession.
- `check --ratchet` never requires a conceded case and doesn't suggest adding it to the ratchet.
- A case is in the ratchet or conceded, never both. An id with no case, or a line without a reason, fails `check` like an unknown ratchet id.
- Concede only after the golden shows upstream's behaviour is the bug, and say what r2ui does instead.

## Mistake-proofing

`.github/workflows/conformance.yml` has two jobs: `ratchet` runs `bin/conformance check --ratchet`, and `goldens` re-records every golden from the real gems on ubuntu-latest (the gems ship prebuilt x86_64-linux binaries) and fails if anything differs from the committed goldens, so an edited, stale, missing or orphaned golden can't merge. A full `bin/conformance record` also deletes goldens whose case is gone.
