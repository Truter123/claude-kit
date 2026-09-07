# 0004 — One global skill: refresh-docs

Status: accepted
Date: 2026-09-04

## Context
The `skills/` and `workflows/` layers were removed from `~/.claude` on 2026-09-04. One of the deleted
skills, `/roma fundatio`, was the generator of `docs/roma/*.md` in three projects (nlp,
deployment-panel, next-class). Deleting the generator left ~2900 lines of generated documentation
with no way to refresh it: within a day `domain-map.md` was asserting that a file which exists does
not, and `CONTEXT.md` was counting 21 ADRs against 27 on disk. A generated doc set with no generator
does not stay still; it rots and then actively misleads.

The same sweep renamed the Latin vocabulary (roma, provincia, leges, glossarium, quaestiones,
decretum) to plain names and collapsed each project's doc set from 6–8 files to three:
`docs/domain/{overview,business-rules,flows}.md`.

## Decision
Reintroduce `~/.claude/skills/` for exactly one skill, `refresh-docs`, which regenerates those three
files from the code-navigator graph, one `engineer` per doc, preserving any open question the user
has answered inline. The skill owns the tier rule it enforces: `docs/domain/*` is the source of
truth, `.claude/rules/{rules,glossary}.md` its compact always-loaded digest, `CONTEXT.md` the
one-page index; edits go into the catalogue first and are copied down.

Any further skill needs its own ADR. The `workflows/` layer stays deleted — a workflow spawns agents
by the dozen, which is the cost the 2026-09-04 removal was about.

## Consequences
The doc set has an owner again and drift becomes a command rather than a rewrite. Cost: `skills/`
exists once more, so the "no skills layer" simplification is gone and the directory will attract
additions — hence the one-ADR-per-skill rule. `refresh-docs` depends on the code-navigator graph; on
a project with no graph it reports `blocked` rather than falling back to grep, which means an
unindexed project cannot use it at all.
