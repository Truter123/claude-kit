---
name: project-sweep
description: >
  Answer a broad, loosely-phrased request to understand a whole project at once - "research my
  codebase", "find duplication", "check the flow between X and Y", "what's weak in this
  architecture", "analyze my project" - even when the user is vague, casual, or typos the
  request ("check totaly flow worker and machine and work research show me flow"). Make sure to
  use this skill whenever a research request spans MULTIPLE angles of a project (duplication,
  coupling, dead code, cross-component flow, architecture risk) rather than one specific
  question, and no formal deliverable is named. Not for one answerable question ("who calls X",
  "where is Y defined") - that stays a single inline cg_node/cg_search call or one scout. Not for
  "what should I refactor" or a request for a written plan - this skill stops at understanding.
---

# Project sweep

A one-shot, read-only pass across several angles of a project, merged into one chat answer.
This exists because "research my whole code and find X" is one of the most common shapes of
request and today it either turns into several ad hoc `scout` calls in a row or one `scout` call
that tries to answer five questions at once and does none of them well. This skill owns that
broader shape; a single question still goes straight to `cg_node`/`cg_search` or one `scout`.

Never writes a file. If the answer turns out to be "there is a lot to refactor here", say so and
name the hotspots - this skill stops at understanding, not prescription.

## 1. Confirm the project and the angles

Resolve the project path (ask if ambiguous). If `navigators/code/code-navigator.db` is missing,
run `bash ~/.claude/hooks/cg-sync.sh "<project path>"` once before anything else.

Read what the user actually asked for, even through typos - "find duplication", "check the flow
worker and machine", "what's rotten", "analyze architecture" each pick a different subset of the
angles below. Do not run every angle by default; run the ones implied by the request, plus
`cg_map` for orientation. If the request is genuinely "just tell me about this project", run all
of them.

## 2. Graph angles - direct calls, no subagent

These are cheap, single `cg_*` calls; make them inline the way the main loop always does for one
graph lookup:

- `cg_map` - orientation: tier, node counts, root aggregates/controllers.
- `cg_health kind=hotspots` - god classes, high fan-in/fan-out.
- `cg_health kind=dead` - unreferenced code.
- `cg_health kind=coupling` - packages/classes that are suspiciously entangled.
- `cg_deps` - declared libraries and how much of each is actually used.

## 3. Duplication - no native graph angle

`cg_health` has no "duplication" kind; the graph tracks structure, not repeated shape. If the
user asked about duplication, spawn one `explorer` (haiku, read-only) for a bounded grep sweep of
the project for repeated method signatures or near-identical blocks - name the file glob and a
result cap in the prompt so it stays one bounded sweep, not an open-ended search. Skip this step
entirely if duplication was not asked about; it is the one angle worth its own delegation.

## 4. Cross-component flow - bounded scouts, parallel

A request like "check the flow between worker and machine" needs traversal the graph tools alone
don't summarize on their own. Break it into at most 3 concrete sub-questions (e.g. "how does the
worker dispatch into the machine aggregate", "what does the machine emit back") and fan them out
to that many `scout` agents in parallel, each with `projectPath` and one question, same as any
other scout delegation. Do not spawn a fourth; if the flow genuinely needs more than 3 hops,
report what the 3 found and name the next hop as a follow-up instead of spawning more.

## 5. Answer once, in chat

One consolidated answer, sections only for the angles actually run. Each section: 3-5 lines with
file:line pointers, not the full `cg_health` dump - summarize, the graph already did the counting.
End with one line naming the strongest next step: a single follow-up `scout` question if one
thread needs a deeper look, or nothing if the sweep answered it.

## Not for

- One answerable question - `cg_node`/`cg_search` inline, or one `scout` call.
- Reviewing a diff - `/code-review`.
