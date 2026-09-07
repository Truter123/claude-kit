# 0001 — External search on the advisor rung only

Status: accepted (agent names updated 2026-09-04 to match ADR 0003)
Date: 2026-09-04

## Context
The brave-search and reddit MCP servers are registered at user level in `~/.claude.json` and connect
at session start, but no agent lists them in its `tools:` frontmatter and `settings.json` does not
permit them, so they are unreachable from a subagent. Design questions that need outside precedent
(library comparison, community pattern, an ADR with no in-repo prior art) otherwise get answered from
model memory with no source. `scout` is defined by its description as a code-graph researcher, and
widening it would blur the graph-first rule in `CLAUDE.md`.

## Decision
Grant external search (`mcp__brave-search`, `mcp__reddit`) to the advisor rung alone — the read-only
model the main loop consults via `/advisor` — as a fallback after the code graph,
`.claude/rules/project.md`, `.claude/rules/rules.md` and the ADR index have failed to settle the
question. Budget: at most 3 external calls per invocation, and only when the question introduces a
new dependency, integration or pattern. Every claim so obtained carries its source URL.
`engineer`, `scout` and `worker` get no external search.

## Consequences
Design answers and ADRs gain citable outside precedent; the graph-first discipline is preserved
because only the advisor, not the builders, can leave the repo. Cost: advisor calls may be slower and
depend on a live Brave API key at `/home/kamil/Documents/Tools/searching/.brave-key` and on the local
reddit-mcp process; both failures must degrade to answering from judgement, not to a retry loop.
Nothing throttles reddit calls beyond the 3-call budget, which is a prose rule with no enforcement.
