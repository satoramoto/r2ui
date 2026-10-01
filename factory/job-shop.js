export const meta = {
  name: 'r2ui-job-shop',
  description: 'Run 2 job shop: typed work orders routed through spec/build/inspect/integrate stations with circuit breakers and a live supervisor',
  phases: [
    { title: 'Spec', model: 'sonnet' },
    { title: 'Build' },
    { title: 'Inspect', model: 'sonnet' },
    { title: 'Integrate', model: 'sonnet' },
    { title: 'Supervise' },
  ],
}

const REPO = '/Users/ryan/The Source/r2ui'
const WT = '/Users/ryan/The Source/r2ui-wt'
const SOP = `${WT}/process/factory/stations`
const cfg = args.config
const orders = args.orders

// ---- shared line state -------------------------------------------------
// budget.spent() is the whole session's output tokens; the run is measured from launch.
const BASELINE = budget.spent()
const spent = () => budget.spent() - BASELINE
const record = []            // finished orders: {id, outcome, firstPass, stations, problems}
let stopped = null
let runCap = cfg.run_output_tokens
let finishedSinceSupervise = 0
const done = {}              // id -> promise resolving to outcome
const resolvers = {}
for (const o of orders) done[o.id] = new Promise(r => { resolvers[o.id] = r })

function breakerCheck() {
  if (stopped) return stopped
  if (spent() > runCap) { stopped = `token breaker: ${spent()} output tokens > run cap ${runCap}`; log(stopped) }
  const last = record.slice(-3)
  if (last.length === 3 && last.every(r => !['merged', 'ready-to-merge'].includes(r.outcome))) { stopped = 'quality breaker: 3 orders in a row not merged'; log(stopped) }
  const last5 = record.slice(-5)
  if (last5.length === 5 && last5.filter(r => r.firstPass).length / 5 < 0.4) { stopped = 'quality breaker: first-pass yield < 40% over last 5'; log(stopped) }
  return stopped
}

const sop = name => `Read your standard work first: "${SOP}/${name}.md" (and "${SOP}/README.md" for context). Repo satoramoto/r2ui, main checkout "${REPO}"; AGENTS.md has the project rules and test commands.`

const BUILD = { type: 'object', properties: {
  branch: { type: 'string' }, worktree: { type: 'string' }, pr_number: { type: 'integer' },
  result: { type: 'string', enum: ['ok', 'blocked'] }, ran: { type: 'string' }, notes: { type: 'string' },
  problems: { type: 'array', items: { type: 'string' }, description: 'problems with the process, SOPs, tools or work order (not the product), one line each' } },
  required: ['branch', 'result', 'ran', 'notes', 'problems'] }
const SPEC = { type: 'object', properties: {
  branch: { type: 'string' }, checks: { type: 'array', items: { type: 'string' } }, failing_summary: { type: 'string' },
  problems: { type: 'array', items: { type: 'string' } } }, required: ['branch', 'checks', 'failing_summary', 'problems'] }
const INSPECT = { type: 'object', properties: {
  verdict: { type: 'string', enum: ['pass', 'rework'] }, findings: { type: 'array', items: { type: 'string' } },
  follow_ups: { type: 'array', items: { type: 'string' } }, problems: { type: 'array', items: { type: 'string' } } },
  required: ['verdict', 'findings', 'follow_ups', 'problems'] }
const INTEGRATE = { type: 'object', properties: {
  result: { type: 'string', enum: ['merged', 'rework'] }, reason: { type: 'string' },
  problems: { type: 'array', items: { type: 'string' } } }, required: ['result', 'reason', 'problems'] }
const SUPERVISE = { type: 'object', properties: {
  sop_changes: { type: 'array', items: { type: 'string' } }, stop: { type: 'boolean' }, stop_reason: { type: 'string' },
  run_output_tokens: { type: 'integer' }, observations: { type: 'array', items: { type: 'string' } } },
  required: ['sop_changes', 'stop', 'observations'] }

// Stations can't merge (no review account), so routes end at inspect and the plant manager merges.
const ROUTES = { fix: ['build', 'inspect'], story: ['spec', 'build', 'inspect'], 'story-lite': ['build', 'inspect'],
  doc: ['build', 'inspect'], pr: ['inspect'] }

async function supervise() {
  const r = await agent(`${sop('supervisor')}

The line's record so far (JSON):
${JSON.stringify({ finished: record, output_tokens_spent: spent(), run_cap: runCap, orders_total: orders.length }, null, 1)}

Edit SOP files in "${SOP}" if it will improve the rest of this run. Return your changes, observations, whether to stop, and optionally a new run_output_tokens cap.`,
    { label: `supervise@${record.length}`, phase: 'Supervise', schema: SUPERVISE })
  if (!r) return
  r.sop_changes.forEach(c => log(`supervisor: ${c}`))
  if (r.run_output_tokens) { runCap = r.run_output_tokens; log(`supervisor: run cap now ${runCap}`) }
  if (r.stop) { stopped = `supervisor stopped the line: ${r.stop_reason}`; log(stopped) }
  return r
}

// WIP limit: an order enters the floor only when one leaves, so agent slots go to finishing
// in-flight orders (downstream stations) instead of starting new ones.
let inFlight = 0
const waiting = []
async function admit() {
  while (inFlight >= (cfg.wip || Infinity)) await new Promise(r => waiting.push(r))
  inFlight++
}
function leave() { inFlight--; const next = waiting.shift(); if (next) next() }

// Integration station: every few ready orders, assemble all ready branches on a local
// integration branch and run the whole suite; culprits go back to build.
const INTEGRATION = { type: 'object', properties: {
  passed: { type: 'boolean' }, ran: { type: 'string' },
  culprits: { type: 'array', items: { type: 'object', properties: { order_id: { type: 'string' }, problem: { type: 'string' } }, required: ['order_id', 'problem'] } },
  unattributed: { type: 'array', items: { type: 'string' } }, problems: { type: 'array', items: { type: 'string' } } },
  required: ['passed', 'ran', 'culprits', 'unattributed', 'problems'] }
const ready = []            // {id, branch, entry, o}
let integratedUpTo = 0
let integrating = null
async function integrate(final) {
  if (integrating) await integrating
  if (ready.length === integratedUpTo && !final) return
  integratedUpTo = ready.length
  const batch = ready.map(r => `${r.id} → ${r.branch}`).join('\n')
  integrating = agent(`${sop('integration')}\n\nIntegration worktree: "${WT}/integration" (create it with \`git worktree add --detach "${WT}/integration" origin/main\` from "${REPO}" if missing). Ready orders and branches, merge in this order:\n${batch}`,
    { label: `integration@${ready.length}`, phase: 'Integrate', schema: INTEGRATION, model: 'sonnet' })
  const r = await integrating
  integrating = null
  if (!r) return
  log(`integration of ${ready.length} branches: ${r.passed ? 'green' : `${r.culprits.length} culprits`}`)
  record.push({ id: `integration@${ready.length}`, type: 'integration', outcome: r.passed ? 'green' : 'red', culprits: r.culprits, unattributed: r.unattributed, problems: r.problems })
  for (const c of r.culprits) {
    const item = ready.find(x => x.id === c.order_id)
    if (!item) continue
    item.entry.firstPass = false
    const b = await agent(`${sop('build')}\n\nWork order ${item.id}: ${item.o.input}\n\nBranch \`${item.branch}\`, worktree "${WT}/${item.id}". Existing PR: #${item.entry.pr}.\n\nREWORK from the integration station (your branch breaks when assembled with the other ready orders) — fix only this:\n${c.problem}`,
      { label: `build:${item.id}:integration-rework`, phase: 'Build', schema: BUILD })
    item.entry.stations.push({ st: 'build', ok: b?.result === 'ok' })
    if (b?.result !== 'ok') item.entry.outcome = 'blocked'
  }
}

async function runOrder(o) {
  for (const dep of o.after || []) await done[dep]
  await admit()
  try { return await runOrderAdmitted(o) } finally { leave() }
}

async function runOrderAdmitted(o) {
  const entry = { id: o.id, type: o.type, outcome: 'pending', firstPass: true, stations: [], problems: [] }
  const branch = `job/${o.id}`
  let pr = o.pr || null
  let notes = ''
  let reworks = 0
  const route = [...ROUTES[o.type]]
  try {
    for (let i = 0; i < route.length; i++) {
      if (breakerCheck()) { entry.outcome = 'not-started-or-halted'; break }
      const st = route[i]
      if (st === 'spec') {
        const r = await agent(`${sop('spec')}\n\nWork order ${o.id}: ${o.input}\n\nUse branch \`${branch}\` from origin/main, in a worktree at "${WT}/${o.id}".`,
          { label: `spec:${o.id}`, phase: 'Spec', schema: SPEC, model: 'sonnet' })
        entry.stations.push({ st, ok: !!r }); if (!r) throw new Error('spec died')
        entry.problems.push(...r.problems)
      } else if (st === 'build') {
        const r = await agent(`${sop('build')}\n\nWork order ${o.id} (${o.type}): ${o.input}\n\nBranch \`${pr ? '(the PR\'s existing branch)' : branch}\`, worktree "${WT}/${o.id}".${pr ? ` Existing PR: #${pr}.` : ''}${notes ? `\n\nREWORK — fix only this:\n${notes}` : ''}`,
          { label: `build:${o.id}${reworks ? ':rework' : ''}`, phase: 'Build', schema: BUILD })
        entry.stations.push({ st, ok: r?.result === 'ok' }); if (!r) throw new Error('build died')
        entry.problems.push(...r.problems)
        if (r.result !== 'ok') { entry.outcome = 'blocked'; entry.reason = r.notes; break }
        pr = r.pr_number || pr
      } else if (st === 'inspect') {
        const r = await agent(`${sop('inspect')}\n\nWork order ${o.id} (${o.type}): ${o.input}\n\nPR #${pr} in satoramoto/r2ui.`,
          { label: `inspect:${o.id}`, phase: 'Inspect', schema: INSPECT, model: 'sonnet' })
        entry.stations.push({ st, ok: r?.verdict === 'pass' }); if (!r) throw new Error('inspect died')
        entry.problems.push(...r.problems); entry.follow_ups = r.follow_ups
        if (r.verdict === 'rework') {
          entry.firstPass = false
          if (++reworks > 1) { entry.outcome = 'scrapped'; entry.reason = 'second inspection rework'; break }
          notes = r.findings.join('\n'); route.splice(i + 1, 0, 'build', 'inspect'); continue
        }
      } else if (st === 'integrate') {
        const r = await agent(`${sop('integrate')}\n\nPR #${pr} in satoramoto/r2ui (work order ${o.id}). Build worktree: "${WT}/${o.id}".`,
          { label: `integrate:${o.id}`, phase: 'Integrate', schema: INTEGRATE, model: 'sonnet' })
        entry.stations.push({ st, ok: r?.result === 'merged' }); if (!r) throw new Error('integrate died')
        entry.problems.push(...r.problems)
        if (r.result === 'merged') { entry.outcome = 'merged'; break }
        entry.firstPass = false
        if (++reworks > 1) { entry.outcome = 'scrapped'; entry.reason = `integration: ${r.reason}`; break }
        notes = `Integration failed: ${r.reason}. Merge origin/main into the branch and fix.`; route.splice(i + 1, 0, 'build', 'integrate')
      }
    }
  } catch (e) { entry.outcome = 'scrapped'; entry.reason = String(e) }
  if (entry.outcome === 'pending') entry.outcome = route[route.length - 1] === 'inspect' && entry.stations.at(-1)?.ok ? 'ready-to-merge' : 'unfinished'
  entry.pr = pr; entry.output_tokens_at_finish = spent()
  record.push(entry)
  log(`${o.id}: ${entry.outcome}${entry.firstPass ? ' (first pass)' : ''} — ${spent()} output tokens so far`)
  if (entry.outcome === 'ready-to-merge') {
    ready.push({ id: o.id, branch: `job/${o.id}`, entry, o })
    if (ready.length - integratedUpTo >= (cfg.integrate_every || Infinity)) await integrate(false)
  }
  resolvers[o.id](entry.outcome)
  if (++finishedSinceSupervise >= cfg.supervise_every && record.length < orders.length && !stopped) {
    finishedSinceSupervise = 0
    await supervise()
  }
  return entry
}

await pipeline(orders, o => runOrder(o))
if (ready.length) await integrate(true)
const final = await supervise()
return { stopped, output_tokens: spent(), record, final_supervisor: final }