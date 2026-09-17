# Provenance

`SKILL.md` and `references/*.md` are vendored unchanged from
[agentailor/skills](https://github.com/agentailor/skills), path `agent-eval-cases`, MIT licensed.

- Upstream commit: `52e32ce8657e` (2026-09-16)
- Vendored: 2026-09-17

Refresh with:

```bash
B=https://raw.githubusercontent.com/agentailor/skills/main/agent-eval-cases
curl -sSf $B/SKILL.md -o SKILL.md
for r in elicitation first-run grading vocabulary; do curl -sSf $B/references/$r.md -o references/$r.md; done
```

The skill links once to the upstream `tool-design` skill, which this kit does not vendor. That link
is context, not a dependency — the skill works without it.
