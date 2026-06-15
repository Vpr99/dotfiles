# Subagent Prompts

Copy-paste prompts for the three subagent roles. Replace `[bracketed]` placeholders. Spawn all three with the most capable model available to you, at maximum reasoning effort.

## Contents
- [1. Finder (Phase 1 — stateful)](#1-finder-phase-1--stateful)
- [2. Strategist (Phase 2 — stateful)](#2-strategist-phase-2--stateful)
- [3. Validator (Phase 3 — stateless, one per validation target, in parallel)](#3-validator-phase-3--stateless-one-per-validation-target-in-parallel)

Statefulness: spawn the **finder** and **strategist** once and continue the same conversation when you send review feedback, so they refine their own work instead of re-deriving it. Spawn each **validator** fresh — never continue one — and dispatch them in parallel.

---

## 1. Finder (Phase 1 — stateful)

```
You are finding the load-bearing assumptions in a plan. Think as hard as you can.

GOAL: [restate the goal in 1–2 sentences]

PLAN / INTENDED APPROACH:
[paste the plan or task + approach]

RELEVANT CONTEXT:
[codebase facts, environment, tools, APIs, data the plan touches — only what's needed]

A load-bearing assumption is a claim that passes ALL THREE gates:
- decision-controlling: if false, a planning-level decision changes (architecture,
  subsystem boundary, lifecycle ownership, data model, safety model, deployment/ops
  strategy, API contract, concurrency model, or research direction),
- currently unproven: not already established by the provided context/evidence, AND
- falsifiable: a concrete claim some evidence could prove true or false.

Find EVERY such assumption the plan silently depends on. Be exhaustive, but do not
inflate the list with facts that are merely relevant. Probe the easily-missed categories:
environment/OS/arch, tool availability and versions, API/library contracts and defaults,
data shape and volume, concurrency and ordering, permissions and auth, error/edge behavior,
and "this works the way I remember" beliefs.

Classify late-falsification cost:
- low: if false, implementation can fix a local detail another way.
- medium: if false, a local helper/test/module design changes, but the plan survives.
- high: if false, architecture, boundaries, lifecycle, data model, concurrency, API,
  deployment/ops, or research direction must be rethought.
- critical: if false, the plan risks production data loss/corruption, downtime, security
  exposure, irreversible migration damage, or failed rollback.

For each, output a row:
- claim (the specific, testable statement — not a topic)
- decision controlled (what planning choice relies on it)
- current evidence / uncertainty (why it is not already known)
- late-falsification cost (low | medium | high | critical)
- what would have to change if false
- why you think it's currently unproven

Exclude anything that is not decision-controlling, currently unproven, and falsifiable
(opinions, aesthetics, already-known facts, or details that would only require a small
local implementation adjustment). Return the list only.
```

When you send additions/cuts back, keep it terse: "Add these: …. Remove these (not load-bearing/falsifiable): …. Return the updated list."

---

## 2. Strategist (Phase 2 — stateful)

```
You are assigning each assumption the best way to VALIDATE it. Think as hard as you can.

ASSUMPTIONS (reviewed list):
[paste the ledger claims + decision controlled + current evidence/uncertainty + late-falsification cost]

ENVIRONMENT: [OS/arch, what's installed/buildable/reachable, repo on hand, network/creds available]

Choose, per assumption or safely grouped set of assumptions, the method that most reliably
and cheaply answers THAT question. The goal is not maximum validator count; it is enough
evidence with the least duplicated work.

Default preference order:
  1. run code, observe output   2. inspect code + static analysis
  3. official documentation     4. broader internet

But this is a default, not a reflex. Override it by weighing:
- FEASIBILITY: can it actually be run/inspected here?
- SAFETY: prefer running only when feasible AND non-destructive (no data/money/external
  side effects; use --help/--dry-run/temp copies/sandbox to make it safe). If the only path
  to validate requires a state-changing action, mark it "needs user approval" instead of
  assigning a plain run.
- QUESTION TYPE: deterministic local behavior → run/inspect; dynamic/empirical (footprint,
  latency) → measure repeatedly or use internet for typical values; documented contract → docs;
  real-world/undocumented norm → internet. Locality can flip the tier.
- NECESSITY: high/critical late-falsification-cost assumptions deserve standalone or clearly
  grouped validation. Medium assumptions should be validated only when cheap, risky, or naturally
  grouped. Low-cost implementation details should usually be marked "defer to implementation"
  instead of assigned a standalone validator.
- GROUPING: when one safe command, code inspection, or source can validate several assumptions,
  group them unless the combined task would become ambiguous or weaken the evidence.

When you're not certain a method will resolve it, give an ordered FALLBACK CHAIN
(e.g. "run (foo.sh --help) → inspect (arg parsing) → docs"). One reliable method is fine
when no fallback is needed.

For each assumption output:
- validate now? (yes | grouped with [IDs] | defer) and why
- chosen method (+ fallback chain)
- one-line justification citing feasibility / safety / question type
- the exact first action (command to run, file to inspect, doc/page to read, or query)
```

When you send corrections back: name the assumption, what's wrong with the choice (won't isolate the answer / unsafe to run / wrong tier), and ask for a revised assignment.

---

## 3. Validator (Phase 3 — stateless, one per validation target, in parallel)

Spawn one per validation target with full tool access — usually one high/critical assumption, or a grouped set when one safe action can validate several assumptions cleanly. It may need to run commands, read files, and search the web (not a read-only agent, but it must run only non-destructive commands; see SAFETY below). Fill in every placeholder; the validator has no other context.

```
Validate the assigned assumption(s) and report back. Think rigorously; do not rubber-stamp them.

ASSUMPTION(S) (claim(s) to test):
[ID: exact falsifiable claim]

FOR EACH ASSUMPTION:
- DECISION CONTROLLED: [planning choice that relies on this]
- CURRENT EVIDENCE / UNCERTAINTY: [why it is not already known]
- LATE-FALSIFICATION COST: [low | medium | high | critical, plus short reason]
- WHAT WOULD HAVE TO CHANGE IF FALSE: [stakes]

ASSIGNED METHOD + FALLBACK CHAIN: [e.g. run (foo.sh --help) → inspect (arg parsing) → docs]
CONTEXT NEEDED: [repo path, command, env, doc URL, anything required to act]
SAFETY: run only read-only / non-destructive commands. Do NOT make actual changes — no
deleting, overwriting, or mutating files/data/config, installing packages, or external/
production writes — even if it would help confirm the claim. If validating genuinely
requires a state-changing action, do NOT perform it: report it as a blocked step (the exact
command + why it's needed) for the user to approve, and fall back to the next safe link in
the chain if one exists.

Execute the chain: try the first method; on failure, ambiguity, or inconclusive output,
proceed to the next link. Reach a verdict only on evidence you actually gathered.

Return exactly:
- VERDICT: confirmed | falsified | inconclusive, per assumption ID
- EVIDENCE: the proof — commands run + their output, code quoted with file:line, or
  doc/source quoted with a link. No evidence = not confirmed.
- CONFIDENCE: high | medium | low, with the reason.
- NEW ASSUMPTIONS SURFACED: any new falsifiable dependency you discovered (e.g. "the answer
  depends on the OS" → "we are running on [X]"), or "none".
- BLOCKED ON APPROVAL: any state-changing action that would confirm this but needs the
  user's OK before running — the exact command + why — or "none".
```
