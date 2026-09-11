---
name: refresh-docs
description: Regenerate a project's docs/domain/*.md (overview, business-rules, flows) from the current code, preserving answered open questions. Use when the domain docs have drifted, after a large feature lands, to seed them on a project that has none, or whenever the user says the docs, CONTEXT.md, rules.md or glossary are stale, outdated or wrong, or asks to "document the domain" or "update the docs from the code". Argument = one doc name (overview | business-rules | flows) to refresh just that one, or nothing for all three.
---

# refresh-docs

Three files, no more: `docs/domain/overview.md`, `docs/domain/business-rules.md`,
`docs/domain/flows.md`. They are the source of truth; `.claude/rules/{rules,glossary}.md` is their
compact always-loaded digest and `CONTEXT.md` the one-page index. A fact is written in the catalogue
first and copied down — never the other way round.

## The one rule: never write what the graph already answers

A doc that restates the code graph costs tokens on every read, goes stale on the next commit, and is
worse than the graph because it is a sample. If a `cg_*` call answers the question, the doc says
*which call to make* and nothing else.

**Never in a doc — always a `cg_*` call:**

| Tempting to write | Ask instead |
|---|---|
| the list of aggregates / roots / controllers | `cg_map` |
| a domain-event table (raised by → handled by) | `cg_node <Aggregate>` |
| a class's file:line, signature, fields | `cg_node <Class>` |
| who calls X, what breaks if X changes | `cg_related <X>` |
| a hotspot / blast-radius ranking | `cg_health(kind: hotspots)` |
| the frontend slice or component inventory | `cg_map` |
| a controller → handler → aggregate call chain | `cg_related <Controller>` |
| every endpoint a controller exposes (verb + path) | `cg_node <Controller>` — its `### Endpoints` section |
| a view-table or repository inventory | `cg_map` |

A partial version of any of these is the worst case: "6 of 161 events" reads as the catalogue and is
wrong. Drop it rather than sampling it.

**Only in a doc — the graph cannot hold it:** why a rule exists and what breaks without it; BR ids
and their statements in business language; **every money or time formula, with its scoping window,
whether it is computed live or projected onto a column, and its null rule** (the graph shows a
method body; it cannot say that this method is the authoritative formula, that the window is the
session and not the day, or that a missing input means null rather than zero); bounded-context
boundaries and responsibilities;
cross-context relations no single node shows; the schema and migration *policy* (forward-only, what a
rename meant, which tables are exceptions); external systems with owner, credentials, config key and
auth; environment variables and what changes when they change; deployment; open questions; anything
decided in an ADR.

Each doc opens with a short "ask the graph for structure" table naming the calls, so a reader knows
where the boundary is.

## 1. Locate

Read `<project>/.claude/rules/project.md`. Its frontmatter `docs:` key names the directory; default
`docs/domain` if the key is absent. If `project.md` itself does not exist, stop and say so — the
project doc has to be written first, this skill does not invent one.

## 2. Graph preflight

`mcp__code-navigator__cg_health` with `projectPath` set to the project root. No graph →
`bash ~/.claude/hooks/cg-sync.sh "$PWD"` once, then re-check. Still nothing → report `blocked`; do
not fall back to grep-and-read for a whole doc set, it costs more than it returns.

The graph covers Java, TypeScript, Groovy and Dart — a Flutter app is indexed like any other client
(widgets as `FE_COMPONENT`, its CQRS classes as `COMMAND`/`QUERY_HANDLER`), so a mobile client is
never a reason to hand-write structure. Two known limits worth remembering before trusting a count:
node ids are bare simple names, so two same-named classes in different packages collide; and Dart
call binding is conservative (~67% of call sites), so an absent `CALLS` edge is not proof of no call.

## 3. Preserve answers

For each doc you are about to rewrite, read its `## Open questions` section. Every question whose
`_answer:_` line is **non-empty** goes into that doc's rewrite prompt as established fact — the
answer becomes prose in the body and the question disappears. Questions with an empty `_answer:_`
are dropped from the prompt; they will be re-raised only if still unprovable.

## 4. Rewrite — one `engineer` per doc

Spawn at most 3 `engineer` agents, all in one message. Each prompt is the whole spec and contains:

- the absolute path of the one file it owns, and that it may write no other file;
- the graph calls to make (`cg_map`, `cg_context`, `cg_related`, `cg_node`), always with
  `projectPath`;
- "read `<project>/.claude/rules/glossary.md` first and use only its binding terms; a term's `not:`
  synonyms are forbidden";
- the answered questions from step 3;
- the line budget;
- the rule above, verbatim: **anything a `cg_*` call answers is named as a call, not written out**;
- **verify every claim against the graph. If the graph contradicts it, drop it; if the graph cannot
  settle it, add it to `## Open questions` with an empty `_answer:_` rather than guess.**
- for `business-rules.md` only: **find every derived figure and give it a `BR-CALC-###` id.** Sweep
  `cg_search` for `*Calculator`, `*Calculations`, `recalculate*`, `compute*`, `sum*`, and for the
  projection handlers that write money columns. Read the method body — a formula is the one thing
  here that must be transcribed, because a reader cannot be sent to `cg_node` for arithmetic they
  need to compare against a ticket. Two figures with the same word in their name and different
  formulas (a table drop, a session drop total, a reported periodic drop) each get their own id and
  say plainly that they do not agree. Where two formulas contradict each other or a name contradicts
  its window, raise it in `## Open questions` — never pick a winner.
- "no meta-commentary about how the doc was generated (no 'sample from cg_node', no 'out of scope
  for this call budget'), no inventory tables, no Latin project vocabulary."

| Doc | Budget | Contents |
|---|---|---|
| `overview.md` | 150 lines | the graph-call table; bounded contexts and their responsibilities; the handful of aggregate facts the code shape does not show (a derived status, an invariant, what "deleted" means); cross-context relations; `## Data` (event-store design, which tables are exceptions, migration policy); `## Integrations` (external systems with auth and config key, env vars); `## Deployment` |
| `business-rules.md` | 200 lines | BR catalogue in two halves. **Guards** as `BR-<AGG>-###`: id, the rule in business language, why it exists, the class that enforces it as a lookup key. Then a `## Calculations` section as `BR-CALC-###`, one id per money or time figure the service derives: the formula, its scoping window, live vs projected onto a `*_view` column, and its null rule. No file:line, no call chains |
| `flows.md` | 80 lines | one entry per business flow: its trigger, its entry endpoint, and the non-obvious fact about it (an auth difference, a cascade, a failure mode). The call chain itself is `cg_related <Controller>` — do not transcribe it |

One endpoint line per flow is correct and stays: it is the flow's identity and the reader's handle.
What must never appear is an endpoint *inventory* — a table of every route a controller exposes.
That is `cg_node <Controller>`, which now renders an `### Endpoints` section.

Each doc ends with its own `## Open questions` section, numbered `Q-01`, `Q-02`, … each followed by
an `_answer:_` line. There is no separate questions file — answering inline and re-running this
skill is the whole workflow.

## 5. Reconcile the digest — main loop, no agent

Do this yourself; it is a handful of edits and delegating it invites drift:

- re-derive `.claude/rules/rules.md` from the new `business-rules.md` (id + one-line rule +
  enforcement site, nothing else, and every `BR-CALC-###` with its formula — a formula the digest
  omits is a formula nobody loads);
- reconcile `.claude/rules/glossary.md` against the new catalogue. It is the naming authority and
  always loaded, so a wrong window or a wrong formula there outranks the docs in practice. Two
  passes: every term marked `(draft: define me)` whose code now exists gets its real definition and
  a `BR-CALC-###`/`BR-<AGG>-###` citation; every term that states a formula, a window or a scope
  gets checked against the catalogue and corrected. A term whose name contradicts its own
  definition ("Business Day Result" that no day scopes) is corrected in the definition and left as
  an open question in the catalogue — never renamed here;
- re-check the always-loaded claims in `.claude/rules/project.md` against the repo: the ADR count
  and which ADRs matter, the test commands, and every line in its Traps section. These rot silently
  because nothing runs them — a trap describing a staged deletion that has since been committed, or
  a broken wrapper that has since been restored, misleads every future session;
- refresh `CONTEXT.md`'s rule highlights, flow list and doc links;
- check every link in `CONTEXT.md`, `CLAUDE.md` and `.claude/rules/*.md` still resolves.

## 6. Report

One line per doc: `refreshed` / `unchanged` / `blocked`, its new line count, and how many unanswered
questions it now carries — plus one sentence telling the user to answer them inline and re-run.

Then, separately, every place where the code contradicted a doc, a glossary term or an always-loaded
rules file, and what you changed it to. That list is the value of the run: a doc that merely got
longer told the user nothing they did not have.
