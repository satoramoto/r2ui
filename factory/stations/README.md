# Station SOPs (standard work)

Run 2 is a job shop: stations are grouped by the kind of work, not by product area. A work order carries its routing (a traveler); the dispatcher (a Workflow script) moves it from station to station. Each station agent reads its SOP here before working. The supervisor station may edit these files mid-run; the next work order picks up the change.

| Station | Does | Model |
|---|---|---|
| `spec` | Turns a work order into acceptance checks that fail today | Sonnet |
| `build` | Makes a work order's acceptance checks pass; one small PR | Opus |
| `inspect` | Reviews the PR: passes it or sends it back with reasons | Sonnet |
| `integrate` | Waits for CI, merges, or sends it back (conflict, red CI) | Sonnet |
| `supervisor` | Every few finished orders: reads the line's numbers, edits SOPs, can stop the line | Opus |

Routings:
- `fix` (a GitHub issue): build → inspect → integrate
- `story` (a capability): spec → build → inspect → integrate
- `doc`: build → inspect → integrate

A work order may go back to `build` once (rework). A second failure scraps it and the dispatcher reports it.

## Circuit breakers (in the dispatcher)

- **Tokens:** a cap for the whole run and per work order. A work order over its cap is scrapped; the run stops dispatching when it passes the run cap.
- **Quality:** the line stops (no new work orders; in-flight ones finish) when 3 work orders in a row end scrapped, or first-pass yield over the last 5 finished is under 40%.
- The supervisor can also stop the line.
