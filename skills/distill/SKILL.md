---
name: distill
description: Cluster the user's own recurring typed prompts from history.jsonl and judge, per cluster, whether it is worth turning into a skill. Use when the user asks "distill", "what do I ask most", "recurring prompts", "which skills should I create", "mine my prompts", or "co najczęściej pytam". Argument = optional --days N (default 30) and --project <path> (exact match). Writes nothing, never calls skill-creator; answers in chat with at most 5 clusters and one verdict each.
---

# distill

One scan of `history.jsonl`, no file written. `scripts/prompts.sh` filters and truncates the
user's own typed prompts to a TSV, the main loop (or one `explorer` on a big TSV) clusters them
by shape, and the answer in chat names, for each cluster, an existing skill to extend, a new
skill to sketch, or "not worth a skill".

## 0. Arguments

`/distill [--days N] [--project <path>]`. Default `--days 30`, no project filter.

## 1. Pull the prompts

`bash ~/.claude/skills/distill/scripts/prompts.sh $ARGS > /tmp/distill-prompts.tsv; wc -l < /tmp/distill-prompts.tsv`.
Never read `history.jsonl` inline; the script is the only reader.

## 2. Cluster

- **≤ 300 lines:** read `/tmp/distill-prompts.tsv` and cluster inline.
- **> 300 lines:** spawn ONE `explorer` (haiku, read-only) with the TSV path and this exact
  task: group by prompt shape (verb + object), return at most 300 lines, per cluster a count, a
  one-line shape, and 2 example prompts truncated to 120 chars. Never `scout`; this is not a
  code question.

Cluster by shape, not exact string: model judgement on the verb + object pattern, not a text
diff. Ignore one-off prompts that share no shape with anything else.

## 3. Answer in chat, nothing written

Top at most 5 clusters, each:

```
<count> × <one-line shape>
  e.g. "<example 1, ≤120 chars>"
  e.g. "<example 2, ≤120 chars>"
  verdict: extend <existing skill> | new skill: <name>, <one-line trigger description>, <5-line body sketch> | not worth a skill (<reason>)
```

`extend <existing skill>` only names a skill that already exists under `~/.claude/skills/`.
Last line: `Next: hand <name> to skill-creator to draft it` for the top verdict that names a
skill, or `Next: nothing to draft` if every cluster is "not worth a skill".

## Not for

Not code review, not memory, not transcript search — it reads `history.jsonl` only, never the
full session transcripts under `projects/`.

## Limits

`history.jsonl` is undocumented (its fields are inferred, not a stable contract); prompts are
truncated at 200 chars by the script; pasted content (`pastedContents`) is excluded.

## Never

- Write any file, project doc or ADR.
- Call `skill-creator` itself; it only names the next action.
- Spawn `scout`, or more than one `explorer`.
- Read `history.jsonl` with any tool other than `scripts/prompts.sh`.
