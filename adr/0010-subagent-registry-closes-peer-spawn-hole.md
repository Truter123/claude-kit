# 0010 — Subagent registry closes the peer-spawn hole in the guard

Status: accepted
Date: 2026-09-09
Amends: 0003

## Context
`hooks/agent-guard.sh` (ADR 0003) ranks the caller against the spawned model. In the main loop the
caller model comes from `settings.json`. Inside a subagent the `PreToolUse` input carries
`agent_id` and `agent_type` but no `model` (docs, https://code.claude.com/docs/en/hooks, checked
2026-09-09), so the guard assumed opus, the highest a subagent can be. A sonnet `engineer` could
therefore spawn a sonnet `scout`: a peer edge the capability graph forbids. The trap was recorded in
`.claude/rules/project.md` and left open.

CLI 2.1.x ships `SubagentStart` and `SubagentStop` events. `SubagentStart` carries the new
`agent_id` and `agent_type`, still no model. But the guard itself sees the model at spawn time
(`tool_input.model`, or the agent file's frontmatter) and the `agent_type` under which the subagent
will start.

## Decision
Two hooks share one registry under `${TMPDIR:-/tmp}/claude-agent-guard-<uid>/<session_id>/`:

- `agent-guard.sh` (PreToolUse on `Agent`) writes every allowed spawn's model to
  `pending/<subagent_type>` (a fork records the caller model, an untyped call records under
  `general-purpose`). Inside a subagent it reads the caller model from `agents/<agent_id>`; an
  unregistered `agent_id` still ranks as opus.
- `hooks/agent-registry.sh` on `SubagentStart` binds `agents/<agent_id>` to the pending model
  for its `agent_type`, else to the agent file's frontmatter model, else opus. On `SubagentStop`
  it deletes the binding; on `SessionEnd` it deletes the session directory. It never blocks.

No other rung, agent file or skill changes. The "exactly six agents" rule of ADR 0007/0008 holds.

## Consequences
A sonnet subagent may now spawn haiku only; a haiku subagent (a `general-purpose` call with
`model: "haiku"`) may spawn nobody. Two parallel spawns of the same `subagent_type` with different
explicit models race on the pending record: the later one wins for both. Custom rung agents pin
their model, so the race only touches built-in types with an explicit `model:`, and the wrong
binding is at most one rung off. The registry lives in `/tmp` and is cleared on reboot and on
`SessionEnd`; a session that dies without `SessionEnd` leaves a small directory behind. The trap
line in `project.md` is replaced by the probe for the subagent case.
