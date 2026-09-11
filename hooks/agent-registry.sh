#!/usr/bin/env bash
# SubagentStart / SubagentStop / SessionEnd handler: keeps the agent registry the guard reads
# (ADR 0010, amends ADR 0003).
#   SubagentStart  binds agent_id -> model. The model comes from the pending spawn record that
#                  agent-guard.sh wrote for this agent_type, else from the agent file's frontmatter,
#                  else "opus" (the old assumption).
#   SubagentStop   deletes the agent_id binding.
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
    AGENT_FILE="/home/kamil/.claude/agents/$AGENT_TYPE.md"
    [ -z "$MODEL" ] && [ -f "$AGENT_FILE" ] && MODEL=$(sed -n 's/^model:[[:space:]]*//p' "$AGENT_FILE" | head -1)
    [ -z "$MODEL" ] && MODEL=opus
    printf '%s\n' "$MODEL" > "$REG/agents/$AGENT_ID"
    ;;
  SubagentStop)
    AGENT_ID=$(printf '%s' "$INPUT" | jq -r '.agent_id // ""' 2>/dev/null)
    [ -n "$AGENT_ID" ] && rm -f "$REG/agents/$AGENT_ID"
    ;;
  SessionEnd)
    rm -rf "$REG"
    ;;
esac
exit 0
