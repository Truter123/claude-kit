#!/usr/bin/env bash
# PreToolUse guard for the Agent tool: enforces the capability graph (ADR 0003).
#   work goes down only   - a spawn must name a model that ranks below the caller
#   peers are not edges   - a fork from inside a subagent is denied
#   every spawn names its model - a bare Agent call is denied
# Caller rank: inside a subagent (agent_id present) the hook input carries no model, so the
# caller model is read from the agent registry that agent-registry.sh fills on SubagentStart
# (ADR 0010): the guard records every allowed spawn's model under pending/<agent_type>, and
# SubagentStart binds it to the agent_id. An unregistered agent_id is assumed to be opus.
# Exit 2 + stderr blocks the call and shows the reason. Always exits 2 on unparsable input.
set -u
SETTINGS=/home/kamil/.claude/settings.json

deny() { echo "capability graph: $1" >&2; exit 2; }

INPUT=$(cat) || deny "guard could not read input"
IN_SUBAGENT=$(printf '%s' "$INPUT" | jq -r 'has("agent_id")' 2>/dev/null) || deny "guard could not parse input"
AGENT_ID=$(printf '%s' "$INPUT" | jq -r '.agent_id // ""' 2>/dev/null) || deny "guard could not parse input"
SESSION=$(printf '%s' "$INPUT" | jq -r '.session_id // "default"' 2>/dev/null) || SESSION=default
REG="${TMPDIR:-/tmp}/claude-agent-guard-$(id -u)/$SESSION"
SUBTYPE=$(printf '%s' "$INPUT" | jq -r '.tool_input.subagent_type // ""' 2>/dev/null) || deny "guard could not parse input"
MODEL=$(printf '%s' "$INPUT" | jq -r '.tool_input.model // ""' 2>/dev/null) || deny "guard could not parse input"

# A custom agent with model: pinned in its frontmatter needs no model in the call.
AGENT_FILE="/home/kamil/.claude/agents/$SUBTYPE.md"
if [ -z "$MODEL" ] && [ -n "$SUBTYPE" ] && [ -f "$AGENT_FILE" ]; then
  MODEL=$(sed -n 's/^model:[[:space:]]*//p' "$AGENT_FILE" | head -1)
fi

rank() {
  case "$1" in
    *fable*)  echo 4 ;;
    *opus*)   echo 3 ;;
    *sonnet*) echo 2 ;;
    *haiku*)  echo 1 ;;
    *)        echo 0 ;;
  esac
}

# Record an allowed spawn so SubagentStart can bind the new agent_id to its model.
record() { mkdir -p "$REG/pending" 2>/dev/null && printf '%s\n' "$1" > "$REG/pending/${SUBTYPE:-general-purpose}"; }

if [ "$IN_SUBAGENT" = "true" ]; then
  [ "$SUBTYPE" = "fork" ] && deny "peers are not edges: a fork inherits the caller model; from a subagent that is a peer call"
  CALLER=opus
  [ -n "$AGENT_ID" ] && [ -f "$REG/agents/$AGENT_ID" ] && CALLER=$(cat "$REG/agents/$AGENT_ID")
else
  CALLER=$(jq -r '.model // "opus"' "$SETTINGS" 2>/dev/null) || CALLER=opus
  [ "$SUBTYPE" = "fork" ] && { record "$CALLER"; exit 0; }
fi
CALLER_RANK=$(rank "$CALLER")
CALLER_NAME=$(printf '%s' "$CALLER" | sed 's/.*\(fable\|opus\|sonnet\|haiku\).*/\1/')

[ -z "$MODEL" ] && deny "every spawn names its model: add model: \"haiku\" | \"sonnet\" | \"opus\" (one rung below yours)"
MODEL_RANK=$(rank "$MODEL")
[ "$MODEL_RANK" -eq 0 ] && deny "unknown model '$MODEL': use haiku | sonnet | opus"

if [ "$MODEL_RANK" -ge "$CALLER_RANK" ]; then
  case "$CALLER_RANK" in
    4) MAY="opus | sonnet | haiku" ;;
    3) MAY="sonnet | haiku" ;;
    2) MAY="haiku" ;;
    *) MAY="nobody" ;;
  esac
  deny "work goes down only: caller ranks as $CALLER_NAME and may spawn $MAY, not '$MODEL'"
fi
record "$MODEL"
exit 0
