# 0003 — Capability graph enforced by a PreToolUse hook

Status: accepted
Date: 2026-09-04
Plan: plans/create-something-liek-this-snazzy-heron.md

## Context
Every session ran Fable, the most expensive tier, as the main loop and delegated ad hoc: nothing forced an Agent call to name a cheaper model, and a subagent could fork a peer or inherit the caller model by omitting `model`. Token cost per session was dominated by spawns that inherited Fable.

## Decision
Delegation follows a capability graph: fable > opus > sonnet > haiku, work goes down only, peers are not edges, questions go up one rung. Opus becomes the main loop (`model` in settings.json) and Fable the advisor (`advisorModel`), consulted read-only for architecture, security review and final verdicts. A PreToolUse hook on matcher `Agent` (`hooks/agent-guard.sh`) denies with exit 2 any call that omits `model`, names a model ranking at or above the caller, or forks from inside a subagent. The hook input carries `agent_id` but no model, so inside a subagent the caller is assumed to be opus, the highest a subagent can be. `CLAUDE_CODE_SUBAGENT_MODEL=sonnet` is a safety net for calls the hook does not see.

Each rung below the main loop is a lean custom agent in `agents/`: `engineer` (sonnet, one implementation slice, may spawn `worker`), `scout` (sonnet, read-only research through the code-navigator graph) and `worker` (haiku, one mechanical action). Their models are pinned in frontmatter (the guard reads `model:` from the agent file when the call omits it), their tool lists are trimmed so a spawn costs roughly 17k tokens instead of 60k, and spawn bans are structural: `worker` and `scout` carry `disallowedTools: Agent`. Every rung uses the graph first: the main loop inline, `scout` via the ladders, `engineer` via `cg_guard` before an edit.

## Consequences
A sonnet subagent spawning sonnet is a peer call the guard cannot detect; the prose rule in CLAUDE.md is the only barrier there. The guard depends on `jq`; unparsable input denies, never allows. A bare `Explore`/`Plan` call now fails until `model` is added, so every delegation prompt in CLAUDE.md names one. Advisor calls bill at Fable rates and require the Anthropic API (Bedrock/Vertex lose the advisor). The advisor cannot be capped at two calls per agent from a hook; that limit is prose only. The `agents/` layer, removed the same morning, returns with exactly three files; `skills/` and `workflows/` stay gone. A `manager` (opus) agent is not added: it would be a peer of the Opus main loop and the guard would deny it.
