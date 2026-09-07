# 0007 — Explorer rung for sweeps the code graph does not cover

Status: accepted
Date: 2026-09-06
Plan: plans/add-agent-explorer-smooth-liskov.md

## Context
In plan mode the main loop kept spawning the built-in `Explore` agent for read-only sweeps the code
graph cannot answer: grep one script across every project, check a `.mcp.json` ignore status, list
`release/` directory sizes and git state. Each run cost 42–93k tokens (screenshot, 2026-09-06):
`Explore` is a general-purpose agent with the full tool list, no stop rule and no report format.
Neither existing rung fits. `scout` is graph-only by contract ("grep never") and refuses off-graph
sweeps; `worker` does one fully specified action and never draws a conclusion. The main loop was
doing the sweeps through the most expensive agent in the CLI.

## Decision
Add a fourth lean agent, `agents/explorer.md`: haiku, read-only (`tools: Read, Grep, Glob, Bash`,
`disallowedTools: Agent, Edit, Write`), one bounded sweep across files, directories or repos where
the graph does not apply, a stop rule of 10 tool calls and 3 file reads, a report of at most 20
lines that leads with the conclusion. The model is pinned in frontmatter so `hooks/agent-guard.sh`
admits it from every caller (haiku ranks below all of them). The built-in `Explore` is no longer
used from the main loop; built-in `Plan` stays allowed on `model: "sonnet"`. `engineer` still
spawns `worker` only. ADR 0003's "exactly three files" in `agents/` is amended to four; any further
rung needs its own ADR.

## Consequences
Off-graph sweeps drop from a ~60k general-purpose spawn to a ~17k lean one with a hard cap on tool
calls. Haiku may miss nuance in what it reads; the contract is "answer the narrower reading and
name the other", and the main loop escalates to `scout` (graph) or reads the named lines itself.
The glossary term `explorer`, previously a forbidden synonym of `scout`, becomes its own term:
`scout` is the graph rung, `explorer` the file-system rung. The memory note "do not add a fourth
agent" is superseded by this ADR.
