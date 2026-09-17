#!/usr/bin/env bash
# Refresh the code-navigator index for one project. Called from Claude Code hooks (SessionStart).
#
# Usage: cg-sync.sh [project-root]      (default: $PWD)
#
# Picks between:
#   sync  - incremental re-index (~25-45 s on a 2,000-file repo); prunes deleted/moved files too.
#   init  - full clean rebuild (~45 s), used when git shows a .java/.ts/.groovy file deleted or
#           renamed since the last indexed commit (recorded in navigators/code/.last-head).
# First run on an indexable repo auto-inits and builds the index. Every run gitignores navigators/ and wires up .mcp.json.
# Skips the home directory and any project without an index. Always exits 0.

set -u
JAR="${CODE_NAVIGATOR_JAR:-$HOME/Documents/Tools/code-navigator/jars/code-navigator.jar}"
P="${1:-$PWD}"

[ "$P" = "$HOME" ] && exit 0
git -C "$P" rev-parse --show-toplevel >/dev/null 2>&1 || exit 0
DB="$P/navigators/code/code-navigator.db"
STAMP="$P/navigators/code/.last-head"

ensure_mcp_json() {
  local mcp_json="$P/.mcp.json"
  if grep -q '"code-navigator"' "$mcp_json" 2>/dev/null; then
    return 0
  fi
  [ -f "$mcp_json" ] || echo '{"mcpServers":{}}' > "$mcp_json"
  MCP_JSON="$mcp_json" JAR="$JAR" P="$P" python3 -c "
import json, os
mcp_json = os.environ['MCP_JSON']
with open(mcp_json) as f:
    data = json.load(f)
data.setdefault('mcpServers', {})['code-navigator'] = {
    'command': 'java',
    'args': ['-jar', os.environ['JAR'], 'serve'],
    'env': {'CODE_NAVIGATOR_PROJECT': os.environ['P']},
}
with open(mcp_json, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
" 2>/dev/null
}

mode=sync
head=""

ensure_excluded() {
  local exclude
  exclude="$(git -C "$P" rev-parse --git-path info/exclude)"
  mkdir -p "$(dirname "$exclude")"
  touch "$exclude"
  grep -qxF 'navigators/' "$exclude" || echo 'navigators/' >> "$exclude"
}

if [ ! -f "$DB" ]; then
  git -C "$P" ls-files | grep -qE '\.(java|ts|groovy|dart|py|sql|sh)$' || exit 0
  mode=init
  echo "cg-sync: first-time init $P"
else
  if git -C "$P" rev-parse --verify HEAD >/dev/null 2>&1; then
    head=$(git -C "$P" rev-parse HEAD)
    if [ -f "$STAMP" ]; then
      last=$(cat "$STAMP")
      if [ "$last" != "$head" ] && git -C "$P" cat-file -e "$last" 2>/dev/null; then
        if git -C "$P" diff --name-status --diff-filter=DR "$last" "$head" \
           | grep -qE '\.(java|ts|groovy|dart|py|sql|sh)$'; then
          mode=init
        fi
      fi
    fi
  fi
fi

# Idempotent; also repairs projects whose index predates .mcp.json wiring.
ensure_excluded
ensure_mcp_json

echo "cg-sync: $mode $P"
if timeout 900 java -jar "$JAR" "$mode" "$P" >/dev/null 2>&1; then
  [ -n "$head" ] && printf '%s\n' "$head" > "$STAMP"
fi
exit 0
