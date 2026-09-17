# 0011 — `distill` skill: cluster recurring prompts from `history.jsonl`

Status: accepted
Date: 2026-09-16

## Context
A Vercel talk on Anthropic's "D0" data agent (now Eve) described a recurring job that distils
the most frequent recurring prompts into skills (roughly 100 of them), so a run starts with
context already loaded. This repo has no equivalent: `skill-creator` only builds a skill by
hand, one at a time, and nothing surfaces what the user actually keeps asking across 30
projects. `~/.claude/history.jsonl` holds every typed prompt (`display`, `pastedContents`,
`timestamp` in epoch ms, `project`, `sessionId`) at 594 KB, against 760 MB of full session
transcripts under `projects/*/*.jsonl`. `history.jsonl` is undocumented (no schema, referenced
only in anthropics/claude-code#41263), but its size and flat shape make it the practical source
for a recurring-prompt scan; the transcripts are not.

## Decision
Add one global skill, `skills/distill/`, read-only and chat-only. `scripts/prompts.sh`
(bash + jq, `set -eu`) filters `history.jsonl` to typed, non-slash-command prompts newer than
`--days N` (default 30), optionally scoped to `--project <path>`, and prints a sorted TSV of
`date`, `project`, `display` truncated to 200 chars. It is the only reader of
`history.jsonl`; a missing file exits 1 with the fallback path named
(`~/.claude/projects/*/*.jsonl`, not implemented) so the skill fails loudly instead of guessing.
`SKILL.md` runs the script once, clusters the TSV inline when it is at most 300 lines or through
one `explorer` sweep above that, and answers in chat with at most 5 clusters: count, two
truncated examples, and one verdict per cluster — `extend <existing skill>`, `new skill: <name>,
<trigger>, <body sketch>`, or `not worth a skill (<reason>)`. It never calls `skill-creator`
itself; the last line of the answer names it as the next action, or says there is nothing to
draft.

Amends: ADR 0004 (one global skill), like 0008/0009 did.

## Consequences
No skill is created automatically — `distill` only proposes, so the skill catalogue cannot
sprawl on its own judgement; a human still runs `skill-creator` on the name it suggests. The
skill depends entirely on the undocumented `history.jsonl` format; if a future CLI build drops
or renames its fields, `prompts.sh` fails loudly (missing-file branch, or a jq error the user
can see) rather than returning an empty or wrong report. `project.md`'s skill list, `glossary.md`
(a **Distill** entry with `not: code review, memory, transcript search`) and `adr/README.md` are
amended by the caller, not by this change.
