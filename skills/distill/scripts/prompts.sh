#!/usr/bin/env bash
set -eu

DAYS=30
PROJECT=""

usage() {
  echo "usage: prompts.sh [--days N] [--project <path>] [-h]" >&2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --days)
      DAYS="$2"; shift 2 ;;
    --project)
      PROJECT="$2"; shift 2 ;;
    -h)
      usage; exit 0 ;;
    *)
      usage; exit 1 ;;
  esac
done

HISTORY="${CLAUDE_HISTORY:-$HOME/.claude/history.jsonl}"

if [ ! -f "$HISTORY" ]; then
  echo "distill: $HISTORY not found; fallback = mine ~/.claude/projects/*/*.jsonl (not implemented)" >&2
  exit 1
fi

CUTOFF_MS=$(( ( $(date +%s) - DAYS*86400 ) * 1000 ))

jq -r --argjson c "$CUTOFF_MS" --arg p "$PROJECT" '
  select((.timestamp // 0) >= $c) | select($p=="" or .project==$p)
  | select((.display|type)=="string") | select((.display|ltrimstr(" ")|length) >= 15)
  | select((.display|ltrimstr(" ")|startswith("/"))|not)
  | [((.timestamp/1000|floor)|strftime("%Y-%m-%d")), (.project // ""), (.display[0:200]|gsub("[\t\n\r]";" "))] | @tsv' "$HISTORY" | sort
