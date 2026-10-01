# The r2ui factory

We build software the way a plant builds physical goods, with agents as the workforce. This file is the plant layout: what each factory concept means here, the line we run, and what we measure. `factory/LOG.md` is the production record: what each run cost and what we learned.

## Current product: the Bubble Tea drop-in

Make `require "r2ui/drop_in"` turn r2ui into a pure-Ruby, drop-in replacement for the Ruby Charm stack:

- **bubbletea** (marcoroth/bubbletea-ruby 0.1.4): its Ruby layer (model, commands, messages, runner) is fine; the native `Bubbletea::Program` (raw mode, input, renderer, ~30 functions) is replaced with pure Ruby.
- **lipgloss** (marcoroth/lipgloss-ruby 0.2.2): a wrapper over Go lipgloss; replaced entirely (styles, borders, colors and blending, join/place/align, table, list, tree; ~150 methods).
- **bubbles** and **harmonica** are pure Ruby and must run unchanged on top.

Then (wave 2) the r2ui DSL grows to express everything a Bubble Tea program can: its own loop, keys, commands, styles and components.

## Concept map

| Factory | Here |
|---|---|
| Customer order | The goal above, from the owner |
| Supplier datasheet / reference part | The upstream gems. They are the spec: their behavior is right by definition |
| Bill of materials (BOM) | `conformance/` case list: every public method/behavior, by area, each with an id |
| Work order | One lane's brief: the outcome, the files it owns, the cases it must turn green |
| Plant manager | The orchestrator session: plans the line, balances lanes, integrates, decides |
| Line setup / tooling changeover | The setup PR: CI, layout, stubs. Lands before any station runs |
| Jigs and fixtures | The conformance harness: makes every part measurable the same way every time |
| Gauge / measuring instrument | The byte stream a program writes to its terminal (read off a pty), decoded into a grid of cells; lipgloss strings compared directly |
| Golden sample (reference part) | Outputs recorded from the real gems. Never hand-edited |
| Stations | Agents with one job: case authoring, machining (implementing), inspection (review), rework, packaging |
| Workcell | A lane: one lead plus a swarm of workers on one set of files |
| Conveyor belt | Git branches and PRs carry parts between stations; workflow scripts are belts with fixed routing |
| Kanban / pull | Stations pull the next case batch when they have capacity; nothing is pushed into a full station |
| WIP limit | How many lanes run at once (the machine's cores; Ruby needs no build slots) |
| Takt time | The pace one station must hold so the line doesn't starve or pile up |
| Bottleneck | The slowest station; the one we add capacity to |
| Poka-yoke (mistake-proofing) | CI re-records goldens from the real gems and fails on any diff, so a hand-edited golden can't pass; `drop_in` refuses to load after the real gems |
| Andon cord (stop the line) | A lane that needs a shared-file change stops and asks for a contract PR instead of editing out of its lane |
| First-article inspection | The first part of each new kind gets a full review before the rest of the batch follows its pattern |
| 100% inspection | CI conformance on every PR |
| Sampling inspection | The Sonnet reviewer reads the diff for bugs and rule breaks, not every byte |
| Separation of duties | Case authors never implement; implementers never edit cases or goldens |
| Rework loop | A failing case id maps to its owning lane; one fix agent per batch of failures |
| Scrap | Work thrown away (abandoned branch, rejected approach); logged, not hidden |
| First-pass yield | Share of cases green on the lane's first CI run |
| Line balancing | Re-cutting lanes when one is much longer than the others |
| Shift handoff | One-shot agents; each ends with one report (PR, SHA, what ran, decisions). No standing agents |
| Quality records | `factory/LOG.md` |
| Packaging | Version bump, README drop-in docs, `gem build` |
| Warehouse | `main` |
| Shipping | `bin/gem-push` by the owner (it needs the owner's MFA) |
| Kaizen | After each run, LOG.md says what to change in the next one |

## The line (run 1)

```
setup PR ─► ┌ tooling lane: harness + first cases ┐
            ├ engine lane: Bubbletea::Program      ├─► integrate ─► rework loop ─► package ─► ship
            └ style lane: lipgloss                 ┘      ▲                │
               case-authoring belt (workflow) ────────────┘ ◄──────────────┘
```

Lanes own disjoint files, so they run together and merge in any order:

| Lane | Owns |
|---|---|
| tooling | `conformance/`, `bin/conformance`, `.github/workflows/conformance.yml` |
| engine | `lib/r2ui/compat/bubbletea.rb`, `lib/r2ui/compat/bubbletea/`, `test/compat/bubbletea/` |
| style | `lib/r2ui/compat/lipgloss.rb`, `lib/r2ui/compat/lipgloss/`, `test/compat/lipgloss/` |
| setup (plant manager) | `lib/r2ui/drop_in.rb`, `lib/r2ui/compat/load_path/`, `factory/`, `.github/workflows/ci.yml`, AGENTS.md |

## Flows on trial

We try more than one way of running stations and compare them in LOG.md:

1. **Workcells** (Agent tool): a lane lead per lane, swarming workers inside it. Model-driven routing.
2. **Belt** (Workflow script): fixed routing in code: fan out per area, then fixed next stations. Deterministic, resumable.

Measured per run: wall-clock per station, agents spawned, output tokens where reported, first-pass yield, rework rounds, human touches, scrap.
