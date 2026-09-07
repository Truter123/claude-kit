#!/usr/bin/env bash
# PreToolUse guard for the Agent tool: enforces the capability graph (ADR 0003).
#   work goes down only   - a spawn must name a model that ranks below the caller
#   peers are not edges   - a fork from inside a subagent is denied
#   every spawn names its model - a bare Agent call is denied
# Caller rank: inside a subagent (agent_id present) the hook does not know the model, so the
# caller is assumed to be opus, the highest a subagent can be; sonnet->sonnet peers pass.
# Exit 2 + stderr blocks the call and shows the reason. Always exits 2 on unparsable input.
set -u
SETTINGS="$HOME/.claude/settings.json"

deny() { echo "capability graph: $1" >&2; exit 2; }

INPUT=$(cat) || deny "guard could not read input"
IN_SUBAGENT=$(printf '%s' "$INPUT" | jq -r 'has("agent_id")' 2>/dev/null) || deny "guard could not parse input"
SUBTYPE=$(printf '%s' "$INPUT" | jq -r '.tool_input.subagent_type // ""' 2>/dev/null) || deny "guard could not parse input"
MODEL=$(printf '%s' "$INPUT" | jq -r '.tool_input.model // ""' 2>/dev/null) || deny "guard could not parse input"

# A custom agent with model: pinned in its frontmatter needs no model in the call.
AGENT_FILE="$HOME/.claude/agents/$SUBTYPE.md"
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

if [ "$IN_SUBAGENT" = "true" ]; then
  [ "$SUBTYPE" = "fork" ] && deny "peers are not edges: a fork inherits the caller model; from a subagent that is a peer call"
  CALLER=opus
else
  [ "$SUBTYPE" = "fork" ] && exit 0
  CALLER=$(jq -r '.model // "opus"' "$SETTINGS" 2>/dev/null) || CALLER=opus
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
exit 0
