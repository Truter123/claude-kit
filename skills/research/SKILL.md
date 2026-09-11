---
name: research
description: Answer one outside-world question with sources - library or tool comparison, current docs, what practitioners use and complain about, precedent for a design decision. Fans out to the surfer (Brave web) and lurker (Reddit) agents in parallel and merges their cited reports into one answer in chat. Argument = the question. Use when the user asks to research, look up, compare, google, "find on reddit", "what does reddit say", "best X for Y", "top 10 X", "what do people use for X", or asks for the newest opinions on a tool; also for a follow-up that changes the question after a previous /research. Not for questions about this codebase (scout).
---

# research

One question, two sources, one cited answer in chat. The main loop never runs the search tools
itself: raw results stay in the agents' windows, and only their one-screen reports come back.

## 1. Shape the question

Write the question as one sentence. Note the domain (Java, Spring, Linux, a product name) and
whether the answer is date-sensitive (a version, "current", "still"). List the jargon variants
you already know: acronyms, product names, the plain-English phrasing. If the argument is empty,
ask for the question in one line and stop.

Two shapes need extra care:

- **"For me" questions** ("best skills for me", "which library should I use"): the agents know
  nothing about the user, so the prompt carries the profile - stack and conventions from
  `CLAUDE.md` and `<project>/.claude/rules/project.md`, plus what the user already has, so the
  answer does not recommend duplicates. Say "already has: …, skip those" in both prompts.
- **"Newest" / "latest" questions**: tell `lurker` to spend its live budget with sort by new or
  top-of-month and to name today's date; the corpus is stale for anything younger than a month.

A follow-up message that narrows or changes the question ("now only the AI part", "top 10 of
those") is a new invocation: shape it again and run one fresh fan-out. Reusing the previous reports
answers the old question.

## 2. Fan out

One message, two `Agent` calls, so they run in parallel. Both agents are pinned to `sonnet` in
their frontmatter; `hooks/agent-guard.sh` admits them from the main loop without a `model:` key.

- `subagent_type: "surfer"`. Prompt: the question; what a good answer looks like (which facts,
  which versions, which comparison axes); "primary sources first, a URL on every claim, at most 4
  searches and 3 fetches, report in at most 25 lines".
- `subagent_type: "lurker"`. Prompt: the same question; the jargon variants from step 1 (they
  feed `any_of`); "corpus first, at most 4 live calls, a permalink and date on every claim, mark
  archive results pre-2025-05, report in at most 25 lines".

A `lurker` run can take up to about 4 minutes: each live Reddit call may pause up to ~55 s. That
is the budget, not a hang. Do not spawn a second `lurker` to speed it up.

## 3. Merge

Answer in chat, ADHD shape, first line = the answer. Sections, in this order, nothing else:

1. **Answer** (at most 3 lines).
2. **Evidence** (at most 5 bullets, web and Reddit mixed, strongest first; each bullet ends with
   its URL or permalink and date). Relay claims with their sources unchanged; do not paste the
   agents' reports. A Reddit claim from the archive keeps its `pre-2025-05` label. A `(snippet)`
   claim keeps that label too.
3. **Disagreements** (only if the two agents or their sources conflict; name both sides).
4. **Gaps** (what neither source found; omit if empty).
5. **Next action** (one line, under two minutes).

## 4. Degrade

If one agent returns `blocked: … unavailable`, publish the other half and say in the Gaps section
which source was missing. Do not retry the blocked agent in the same run; the user decides whether
to run `/research` again.

## Never

- Write a file. The result lives in chat.
- Spawn `engineer`, `scout` or a second `surfer`/`lurker` from this skill.
- Call `brave_web_search` or any `reddit_*` tool from the main loop.
- Run more than one round of fan-out per invocation. If the answer needs a follow-up question,
  ask the user and let them run `/research` again.
