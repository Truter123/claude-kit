#!/usr/bin/env bash
# measure.sh - counted evidence for /smell-java.
# Usage: measure.sh <file.java> [<file.java> ...]   (absolute paths; output to stdout)
# One block per file, FILE line last. Java only; other files print SKIP and are estimated by
# the scout. Heuristic counting (brace and regex, no parser): every number names the line
# where the scout can verify it. Never edits anything.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for f in "$@"; do
  if [ ! -f "$f" ]; then echo "MISSING $f"; continue; fi
  case "$f" in
    *.java) echo "== $f"; awk -v FILE="$f" -f "$here/measure.awk" "$f" ;;
    *)      echo "== $f"; echo "SKIP $f (not .java; scout estimates, mark likely)" ;;
  esac
done
