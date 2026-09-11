# claude-kit

My Claude Code setup: six delegation agents, six skills, the hooks that enforce the delegation
order, and the [code-navigator](https://github.com/Truter123/code-navigator) code graph as a
submodule. Copy it into `~/.claude` on any machine.

## What is inside

| Path | What it is |
|---|---|
| `CLAUDE.md` | Global instructions: the capability graph (fable > opus > sonnet > haiku), code questions through the graph, project documents. |
| `agents/` | `engineer` (sonnet, implements one slice), `scout` (sonnet, read-only research on the graph), `surfer` (sonnet, one web question via Brave), `lurker` (sonnet, one Reddit question), `worker` (haiku, one mechanical action), `explorer` (haiku, read-only sweep off the graph). Each has a `color:` for the status line. |
| `skills/` | `refresh-docs` (regenerates `docs/domain/*.md` from the graph), `smell-java` (ranks refactoring candidates by graph blast radius), `research` (fans out to `surfer` + `lurker`), `commit` (one-commit-per-branch style), `jira-task` (how to write a good Jira ticket), `skill-creator` (build and eval skills). |
| `hooks/` | `agent-guard.sh` (PreToolUse on `Agent`: blocks bare, upward and peer spawns), `agent-registry.sh` (SubagentStart/Stop: binds each subagent to its model so the guard sees peers), `cg-sync.sh` (SessionStart: builds or refreshes a project's code graph). |
| `code-navigator/` | Git submodule: the code-graph MCP server (Java). Branch `code-only-navigator`. |
| `rules/adhd.md` | Output rules loaded into every session by the SessionStart hook. |
| `settings.hooks.json` | The `hooks` block to merge into `~/.claude/settings.json`. |
| `mcp.json.example` | The `code-navigator` MCP server entry. `cg-sync.sh` writes this into each project's `.mcp.json` for you. |
| `adr/` | Why things are the way they are (ADR 0001–0010). |

## Install

1. Copy the files:
   ```bash
   git clone --recurse-submodules <this repo> ~/Documents/Tools/claude-kit
   cd ~/Documents/Tools/claude-kit
   mkdir -p ~/.claude
   cp -r agents skills hooks rules adr CLAUDE.md ~/.claude/
   ```
2. Merge the hooks into your settings (creates `settings.json` if missing):
   ```bash
   [ -f ~/.claude/settings.json ] || echo '{}' > ~/.claude/settings.json
   jq -s '.[0] * .[1]' ~/.claude/settings.json settings.hooks.json > /tmp/s.json && mv /tmp/s.json ~/.claude/settings.json
   ```
3. Build code-navigator from the submodule (Java 21+, Gradle wrapper included):
   ```bash
   cd ~/Documents/Tools/claude-kit/code-navigator && ./gradlew build
   mkdir -p jars && cp build/libs/code-navigator-*.jar jars/code-navigator.jar
   export CODE_NAVIGATOR_JAR=~/Documents/Tools/claude-kit/code-navigator/jars/code-navigator.jar   # add to your shell profile
   ```
   Without the variable the hooks look in `~/Documents/Tools/code-navigator/jars/`.
4. Index a project once (later sessions do it automatically on SessionStart):
   ```bash
   bash ~/.claude/hooks/cg-sync.sh /path/to/project
   ```

## Check it works

```bash
bash -n ~/.claude/hooks/*.sh
echo '{"tool_name":"Agent","tool_input":{"prompt":"x"}}' | bash ~/.claude/hooks/agent-guard.sh   # exit 2 = blocked
echo '{"tool_name":"Agent","tool_input":{"prompt":"x","subagent_type":"worker"}}' | bash ~/.claude/hooks/agent-guard.sh   # exit 0
```

Start `claude` in an indexed project: the session opens with the ADHD rules loaded and the
`cg_*` tools available. The graph indexes Java, TypeScript, Groovy and Dart only.

## How the delegation works

Work goes down one rung, questions go up one rung. The main session (opus) plans and integrates;
`engineer` implements one slice with tests; `scout` answers one code question on the graph;
`surfer` and `lurker` answer one outside-world question each (web, Reddit); `explorer` does one
read-only sweep where the graph does not apply; `worker` does one mechanical edit or command.
`hooks/agent-guard.sh` rejects any `Agent` call that does not name a model or that points upward
or sideways. Details and the reasons are in `CLAUDE.md` and `adr/`.
