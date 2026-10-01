# Production log

One entry per run. Facts first (what ran, how long, what it cost, yield), then what to change.

## Run 1: Bubble Tea drop-in (started 2026-10-01)

### Line setup
- Plant manager surveyed the supplier parts directly instead of running a survey station: the native surface is listed by the C `rb_define_method` calls (bubbletea ~30, lipgloss ~150), and bubbles/harmonica turned out to be pure Ruby. That cut the product to two native layers. **Lesson:** read the supplier's datasheet before staffing a survey station; a grep can replace an agent.
- Gauge choice: the owner rejected screen capture; we read the pty byte stream and decode it to a cell grid. lipgloss needs no terminal at all: compare strings.

### Result
- ~50 min to code complete; ~2.0M agent tokens (55% case authoring). Hidden-case yield 665/674, 100% outside 9 concessions (upstream input bugs we fixed on purpose). Rework 1, scrap 1.
- Lessons: a reference implementation as spec makes QA objective; give workers a structured `problems` slot; defects are systematic (fix the tooling, not each worker); balance lanes by work size; inspection costs about as much as production.

## Run 2: Job shop (2026-10-01)

Stations by kind of work (spec, build, inspect, integration, supervisor), typed work orders with routes, dispatcher `factory/job-shop.js`, SOPs in `factory/stations/`.

| Batch | Orders | Agents | Wall | Output tok | Total tok | First pass |
|---|---|---|---|---|---|---|
| Calibration | 7 | ~26 | ~15 min | ~120k | ~1.1M | 7/7 |
| DSL stories | 30 | 83 | 16 min | 541k | 4.7M | 27/30 (29 merged, 0 conflicts) |
| CLI stories | 28 | 65 | 24 min | 538k | 4.0M | 28/28 (4/4 integration green) |

Plus two design stations (DSL, CLI), each reworked once for 3 blockers. `main`: 7,786 tests green.

- **Design for manufacturing replaces lanes:** a design station builds a self-registering extension point first; 58 parallel stories, 0 merge conflicts.
- **Inspect the design:** both design PRs had 3 blockers; the DSL one would have stalled 13 of 30 stories.
- **Integration station:** a story's `R2UI::Ext::Keys` hid `R2UI::Keys` and broke 86 tests only after assembly; now every N ready branches are assembled and tested together.
- **Spec station experiment:** separate Sonnet test-writer + Opus builder (13/15 first pass, +15 agents) vs builder writes tests (14/15). No gain when the spec is the same paragraph; keep it for external references (run 1's goldens).
- **Supervisor:** caught the token-baseline bug, stopped the line when merging was impossible, grew the build SOP from 6 to 16 rules; mistakes didn't recur.
- **Breakers:** token breaker needs a launch baseline (it tripped on session spend); quality breakers never tripped.
- **Authority:** stations can't merge without a review account; "merge yourself" to the plant manager leaked to builders. SOPs now state who merges.
- **WIP:** without a limit everything started and nothing finished; a limit below the agent-slot cap slowed the line (24 min / 28 vs 16 min / 30). Next: WIP = slots, downstream first.
- **Gauge repeatability:** one flaky conformance case (#79) failed an unrelated PR.

Next run: WIP = slots with downstream priority; review bot account so the line merges itself; inspect follow-ups become issues then work orders; supervisor SOP edits reviewed at run end; a hands-off backlog run.
