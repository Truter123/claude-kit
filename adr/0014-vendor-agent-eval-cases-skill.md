# 0014 — Vendor the agent-eval-cases skill

Status: accepted, 2026-09-17

## Context

`skill-creator` builds and runs evals, but it does not answer the question that comes first: which
agent behaviours are worth an eval case at all. Without that, a suite ends up with one case per
feature — expensive, slow, and mostly re-testing what a unit test already covers — and with
negative graders that pass when the agent does nothing.

The `agent-eval-cases` skill (agentailor/skills, MIT) covers exactly that gap: elicit observed
failures rather than invent them, push each failure to the cheapest layer that can catch it, group
by defect class, pair every pushing case with a bounding one, prefer a deterministic check over a
judge, and read the first red run before fixing anything. It is harness-agnostic and explicitly
refuses to scaffold an eval harness without being asked, so it adds no dependency.

Applying it to the personal config's routing suite on 2026-09-17 found two vacuous negative cases,
a missing bound on four agent cases, and one uncovered rule — real defects in a suite that was
reporting 10/10.

## Decision

Vendor `agent-eval-cases` into `skills/`, unchanged, with `PROVENANCE.md` recording the upstream
commit and a refresh command. It sits beside `skill-creator`: this skill decides what to test,
`skill-creator` builds and runs it.

## Consequences

One more skill description loaded into every session (~90 words). The content is four reference
files read on demand, so the standing cost is the description only.

Vendored, not submoduled: the upstream repo holds many skills and this kit wants one. The cost is
that updates are manual — `PROVENANCE.md` carries the command and the pinned commit so a refresh is
a diff, not an archaeology exercise.

The kit's own routing eval suite (`evals/`, `tests/eval.sh`) is not part of this decision and does
not ship here; it stays in the personal config. Numbering skips 0013 for that reason.
