# 0008 — Research agents `surfer` (Brave) and `lurker` (Reddit) behind a `/research` skill

Status: accepted
Date: 2026-09-08
Plan: plans/create-skill-and-agents-goofy-fox.md

## Context
ADR 0001 confined external search to the advisor rung with a budget of 3 calls per invocation, as a
fallback for design questions. That left the main loop with no way to run a bounded research
question ("what do people use for X", "compare A and B", "is Y still current") through a cheap
agent: either the advisor spent its budget on it, or the main loop called the search tools itself
and held raw results in the window that also holds the plan. The reddit server's tool ids, unknown
when ADR 0002 was written, are now observed at runtime: ten tools in three cost classes — a free
local corpus (`reddit_corpus_*`), a live path of about one request per minute (`reddit_search`,
`reddit_read_thread`, `reddit_find_subreddits`, `reddit_subreddit_posts`), and an unthrottled
third-party archive that ends 2025-05-19 (`reddit_search_archive`). Brave exposes one tool,
`brave_web_search`, with snippets only.

## Decision
Add two read-only Sonnet agents, one per source, and one skill that is their only caller pattern.
`agents/surfer.md`: `tools: mcp__brave-search__brave_web_search, WebFetch`, at most 4 searches and
3 fetches, a URL on every claim, snippet-only claims marked. `agents/lurker.md`:
`tools: mcp__reddit`, corpus first, at most 4 live calls, a permalink and date on every claim,
archive claims labelled `pre-2025-05`, and `reddit_corpus_summarise` after every thread it reads so
the corpus grows for the next question. Both have `disallowedTools: Agent, Edit, Write, Bash, Read,
Grep, Glob`, a report of at most 25 lines, and `blocked: <server> unavailable` after one retry.
`skills/research/SKILL.md` fans out to both in one message, merges into a fixed five-section chat
answer (answer, evidence, disagreements, gaps, next action) and writes nothing to disk.

Amendments: ADR 0001's grant to the advisor stands and its rule "`engineer`, `scout` and `worker`
get no external search" still holds; `surfer` and `lurker` are the second holder of external search,
under the same degrade rule. ADR 0007's "four files in `agents/`" becomes six. ADR 0004's "one global
skill" becomes two with ADRs (`refresh-docs`, `research`); `skills/commit/` exists untracked without
an ADR and is not covered here. `settings.json` is unchanged: `mcp__brave-search__brave_web_search`,
`mcp__reddit`, `WebFetch` and `Agent` were already in `permissions.allow`.

## Consequences
A research question costs about two lean spawns (~17k tokens each) plus tool output, all outside the
main window; the main loop reads two 25-line reports. A `lurker` run can take up to about 4 minutes
wall clock because of the Reddit live budget; the skill says so and forbids spawning a second one.
The Brave key at `/home/kamil/Documents/Tools/searching/.brave-key` and the local reddit-mcp
process are external dependencies; both degrade to a half answer, never to a retry loop. The
budgets are prose rules with no hook enforcement, as in ADR 0001. The glossary gains `surfer` and
`lurker`; `researcher` stays a forbidden synonym (of `scout`), so the new rungs are never called
that. ADR 0002's follow-up — narrow `mcp__reddit` to tool ids — is now possible and remains open.
