#!/usr/bin/env bash
# SubagentStart / SubagentStop / SessionEnd handler: keeps the agent registry the guard reads
# (ADR 0010, amends ADR 0003).
#   SubagentStart  binds agent_id -> model. The model comes from the pending spawn record that
#                  agent-guard.sh wrote for this agent_type, else from the agent file's frontmatter,
#                  else "opus" (the old assumption). Also records the start time and agent_type
#                  for the run log.
#   SubagentStop   appends one TAB-separated line to runs.log, then deletes the agent_id binding:
#                    utc_time  session_id  agent_id  agent_type  model  duration_s  tool_calls  top_tools
#                  tool_calls/top_tools come from the agent's transcript (agent_transcript_path)
#                  when readable and <=20MB (counted with jq); above that cap tool_calls falls back
#                  to a grep count and top_tools is "n/a". Logging never blocks the hook: failures
#                  are swallowed.
#   SessionEnd     deletes the session's registry directory.
# Never blocks: always exits 0.
set -u
INPUT=$(cat) || exit 0
EVENT=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // ""' 2>/dev/null) || exit 0
SESSION=$(printf '%s' "$INPUT" | jq -r '.session_id // "default"' 2>/dev/null) || exit 0
REG="${TMPDIR:-/tmp}/claude-agent-guard-$(id -u)/$SESSION"

case "$EVENT" in
  SubagentStart)
    AGENT_ID=$(printf '%s' "$INPUT" | jq -r '.agent_id // ""' 2>/dev/null)
    AGENT_TYPE=$(printf '%s' "$INPUT" | jq -r '.agent_type // "general-purpose"' 2>/dev/null)
    [ -z "$AGENT_ID" ] && exit 0
    mkdir -p "$REG/agents" "$REG/pending"
    MODEL=""
    [ -f "$REG/pending/$AGENT_TYPE" ] && MODEL=$(cat "$REG/pending/$AGENT_TYPE")
    AGENT_FILE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/agents/$AGENT_TYPE.md"
    [ -z "$MODEL" ] && [ -f "$AGENT_FILE" ] && MODEL=$(sed -n 's/^model:[[:space:]]*//p' "$AGENT_FILE" | head -1)
    [ -z "$MODEL" ] && MODEL=opus
    printf '%s\n' "$MODEL" > "$REG/agents/$AGENT_ID"
    date +%s > "$REG/agents/$AGENT_ID.start"
    printf '%s\n' "$AGENT_TYPE" > "$REG/agents/$AGENT_ID.type"
    ;;
  SubagentStop)
    AGENT_ID=$(printf '%s' "$INPUT" | jq -r '.agent_id // ""' 2>/dev/null)
    if [ -n "$AGENT_ID" ]; then
      {
        RUN_MODEL="unknown"
        [ -f "$REG/agents/$AGENT_ID" ] && RUN_MODEL=$(cat "$REG/agents/$AGENT_ID")
        RUN_TYPE=""
        [ -f "$REG/agents/$AGENT_ID.type" ] && RUN_TYPE=$(cat "$REG/agents/$AGENT_ID.type")
        DURATION=""
        if [ -f "$REG/agents/$AGENT_ID.start" ]; then
          START=$(cat "$REG/agents/$AGENT_ID.start")
          NOW=$(date +%s)
          DURATION=$((NOW - START))
        fi
        TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.agent_transcript_path // ""' 2>/dev/null)
        TRANSCRIPT="${TRANSCRIPT/#\~/$HOME}"
        TOOL_CALLS=""
        TOP_TOOLS=""
        if [ -n "$TRANSCRIPT" ] && [ -r "$TRANSCRIPT" ]; then
          SIZE=$(stat -c%s "$TRANSCRIPT" 2>/dev/null || echo 0)
          if [ "$SIZE" -le 20971520 ]; then
            COUNTS=$(jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use") | .name' "$TRANSCRIPT" 2>/dev/null | sort | uniq -c | sort -rn)
            TOOL_CALLS=$(printf '%s\n' "$COUNTS" | awk '{s+=$1} END{print s+0}')
            TOP_TOOLS=$(printf '%s\n' "$COUNTS" | head -3 | awk '{printf "%s%s:%s", (NR>1?",":""), $2, $1}')
          else
            TOOL_CALLS=$(grep -c '"type":"tool_use"' "$TRANSCRIPT" 2>/dev/null)
            TOP_TOOLS="n/a"
          fi
        fi
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
          "$(date -u +%FT%TZ)" "$SESSION" "$AGENT_ID" "$RUN_TYPE" "$RUN_MODEL" "$DURATION" "$TOOL_CALLS" "$TOP_TOOLS" \
          >> "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/runs.log"
      } 2>/dev/null || true
      rm -f "$REG/agents/$AGENT_ID" "$REG/agents/$AGENT_ID.start" "$REG/agents/$AGENT_ID.type"
    fi
    ;;
  SessionEnd)
    rm -rf "$REG"
    ;;
esac
exit 0
