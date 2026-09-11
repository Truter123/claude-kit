# Global instructions

## Delegation: the capability graph

Work goes down, questions go up one rung. Every `Agent` call names its model, either `model:` or
a custom agent whose frontmatter pins it; a bare call, an upward call or a peer call is blocked by
`hooks/agent-guard.sh` (ADR 0003).

| Rung | Does | Agent | May spawn |
|---|---|---|---|
| `fable` | advisor only: architecture, security review, final judge; reads, returns advice, spawns nothing | `/advisor` | — |
| `opus` | the main loop: plan, integrate, decide | (this session) | `engineer`, `scout`, `worker`, `explorer`, `surfer`, `lurker` |
| `sonnet` | one implementation slice with tests (`engineer`); one research question, graph-first, read-only (`scout`); one outside-world question with a source on every claim, read-only (`surfer` Brave web, `lurker` Reddit) | `agents/engineer.md`, `agents/scout.md`, `agents/surfer.md`, `agents/lurker.md` | `engineer` → `worker`; `scout`, `surfer`, `lurker` → nobody |
| `haiku` | one mechanical edit or one command (`worker`); one bounded read-only sweep across files, dirs or repos where the graph does not apply (`explorer`) | `agents/worker.md`, `agents/explorer.md` | nobody (no `Agent` tool) |

- Down only: a change → `engineer`; code research on the graph → `scout`; a file/git sweep off the
  graph → `explorer`; one mechanical action → `worker`; an outside-world question → `/research`,
  which fans out to `surfer` and `lurker` (the main loop never calls the search tools itself); "what
  should I refactor" on a project → `/smell-java`, which ranks graph hotspots through `scout`.
  Built-in `Explore` is not used; built-in
  `Plan` only with `model: "sonnet"`. A fork inherits the caller and is allowed from the main loop
  only.
- Up one rung: a subagent that needs a decision reports `blocked` with one question, never spawns
  upward; at most two such questions per agent. The main loop asks the advisor (`/advisor`, set to
  `fable`) for architecture, security and final verdicts; the advisor is read-only.
- Cost: a lean agent costs about 17k tokens to spawn, a general-purpose one about 60k. Under
  roughly ten tool calls the main loop does the work itself: one-liners, prose and config edits,
  anything already in context.
- Plan mode is the strongest reason to delegate, not a reason to stop: exploration output must stay
  out of the window that holds the plan. Every code question the plan depends on goes to `scout`,
  every sweep across files or repos to `explorer`, one known command to `worker`, and the main
  loop reads only their reports. It writes the plan itself and spawns no `engineer` until the plan
  is approved.
- Prompt is the whole spec (absolute paths, the exact change, the verify command, which glossary to
  read); relay the result unchanged.
- A lookup goes to the graph before any `worker` spawn: one `cg_node`/`cg_search` call is cheaper
  than an agent (next section).

## Code questions go through the graph

"Where is X / how does X work / who calls X / what breaks if I change X": one `cg_node`/`cg_search`
call inline (load both with one `ToolSearch`:
`select:mcp__code-navigator__cg_node,mcp__code-navigator__cg_search`); needing a second call means
delegate to `scout` with `projectPath` and the question. Every rung uses the graph: the main loop
for one inline call, `scout` for the ladders, `engineer` for `cg_guard` before an edit; on an
indexed project grep-and-read is never the first move. Never grep-and-read here. No graph
(`navigators/code/code-navigator.db` missing) → `bash ~/.claude/hooks/cg-sync.sh "$PWD"` once. The
graph indexes Java, TypeScript, Groovy and Dart only; ADRs, business rules and the glossary live in the
repo's `CLAUDE.md`, `CONTEXT.md` and `adr/` — say so when the answer came from there. Skip for a
trivial lookup with a known file and for non-code questions.

## Project documents

`<project>/.claude/rules/project.md` (verified commands, conventions) and `rules.md` (business rules
by BR id, never re-derived) load every session. `glossary.md` is the Ubiquitous Language: binding
for every name in code, tests, API and UI; a term's `not:` synonyms are forbidden. It is
`paths:`-scoped, which this CLI build treats as not auto-loaded: whoever edits code reads it first,
and a delegated agent's prompt says so.

The long form lives in `<project>/docs/domain/` — exactly three files, `overview.md` (contexts,
aggregates, data, integrations, deployment), `business-rules.md` and `flows.md`. That directory is
the source of truth; `.claude/rules/{rules,glossary}.md` is its compact always-loaded digest and
`CONTEXT.md` the one-page index, so a rule is edited in the catalogue first and copied down.
`/refresh-docs` regenerates the three files from the code graph; run it when they have drifted.

A doc never restates the graph. Aggregate and controller inventories, event tables, file:line
pointers, call chains and hotspot rankings are `cg_map` / `cg_node` / `cg_related` /
`cg_health` — writing them down costs tokens on every read and is stale by the next commit. The docs
hold only what the graph cannot: why a rule exists, BR ids and their statements, context boundaries,
schema and migration policy, external systems with their auth and config keys, deployment, and open
questions. When editing a doc, delete any inventory you find rather than updating it.
