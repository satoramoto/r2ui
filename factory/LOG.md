# Production log

One entry per run. Facts first (what ran, how long, what it cost, yield), then what to change.

## Run 1: Bubble Tea drop-in (started 2026-10-01)

### Line setup
- Plant manager surveyed the supplier parts directly instead of running a survey station: the native surface is listed by the C `rb_define_method` calls (bubbletea ~30, lipgloss ~150), and bubbles/harmonica turned out to be pure Ruby. That cut the product to two native layers. **Lesson:** read the supplier's datasheet before staffing a survey station; a grep can replace an agent.
- Gauge choice: the owner rejected screen capture; we read the pty byte stream and decode it to a cell grid. lipgloss needs no terminal at all: compare strings.
