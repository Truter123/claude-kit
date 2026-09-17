# 0012 — scout confirms a negative with one grep

Status: accepted
Date: 2026-09-16

## Context
Eval 2026-09-16 (`skills/evals/cg-vs-grep/runs/nlp-2026-09-16.md`) ran 5 questions × 2 arms on
project `nlp`, both sonnet. Graph-first scout: exact 2/5, partial 3/5 (Q2 who calls, Q3 blast
radius, Q4 end to end), 131k tokens. Grep-only sonnet: exact 5/5, 212k tokens (162 % of cg). The
80 % token gate (relax only if grep is ≥ as correct on ≥4/5 and ≤80 % of tokens) keeps the
graph-first rule: correctness was met, tokens were not (162 %).

The graph misses two kinds of caller edge: `Andon#resolve` ← `ResolveAndonCommandHandler` (scout
reported "no production callers" — wrong) and `SalesOrder#cancel` ← `SalesOrderRepositoryImpl
#delete` (line 65; graph listed only tests). `cg_related direction:in` also returned 55 sibling
methods of `SalesOrder` as "callers" — noise, not signal. On the end-to-end question, scout
stopped the chain at the command handler and `repository.save`, never reaching the event applier,
projection handler or view. A wrong "nobody calls this" costs more than the 20k tokens one grep
would have spent.

## Decision
`agents/scout.md` keeps cg_* first but adds one confirming Grep before a negative or a truncated
chain:
> **Negatives need a grep.** Never say "no caller", "nothing calls this", "dead", or end an
> end-to-end chain on the graph alone: one Grep on `src/main` first, then merge. Measured
> 2026-09-16: the graph misses handler→aggregate and repository→aggregate caller edges, and
> `cg_related direction:in` lists sibling methods as callers.

Route 2 (blast radius) inserts a Grep for `\.<method>(` under `src/main` (plus `src/test` when the
test share matters) between `cg_related direction:in` and `cg_health coupling`, merging any callers
the graph missed. Route 1 (feature) adds a step before ending an end-to-end chain at a command
handler or `repository.save`: one Grep for the emitted event's class name, to reach the applier,
projection handler and view. The "never read a file the graph did not name" rule gets one
exception: the confirming Grep. The stop rule becomes 5 `cg_*` calls, 1 confirming Grep, 3 file
reads.

Amends: ADR 0003 (scout rung as defined there). The graph-first rule in `CLAUDE.md` is unchanged —
cg_* stays the first call on every route.

## Consequences
One extra Grep (a few k tokens) on caller and end-to-end chain questions only; "where is X" and
"what is rotten" routes are unchanged and keep their token lead. The two missing-edge cases
(handler→aggregate, repository→aggregate) should be reported to the code-navigator tool
(`/home/kamil/Documents/Tools/code-navigator`) — out of scope here. `adr/README.md`, `project.md`
and `glossary.md` are amended by the caller, not by this change.
