# 0005 — Own the ADHD rewrite; retire the claudish plugin

Status: superseded by ADR 0006 (2026-09-04, same day) — the local rewrite was removed; only the
SessionStart-loaded `rules/adhd.md` remains
Date: 2026-09-04

## Context
The ADHD output shaping had two owners. `hooks/adhd-hook.md` was a SessionStart prompt telling the
model to write ADHD-shaped answers. The rest was the third-party plugin
`claudish-to-english@gvzdv-plugins` (v0.9.0): a `MessageDisplay` hook that sent every finished
assistant message to local Ollama and replaced it on screen, steered by `hooks/claudish-prompt.md`
through `CLAUDISH_PROMPT_FILE`.

Two problems. The rules existed twice in different words — ten numbered rules in one file, a format
spec plus a few-shot pair in the other — and had already begun to drift. And the working half was
upstream code: a plugin release can change chunk buffering, the skip gate or the meaning of
`replace`, and `hooks/claudish-probe.sh` reached into `plugins/cache/**/0.9.0/rewrite.sh`, a path
that breaks on the next version. The plugin also carried features never used here: three style
presets, output-language switching, markdown-file rewriting, and anthropic/openai/codex providers.

CLI 2.1.260 implements `MessageDisplay` and `hookSpecificOutput.displayContent` in the binary, so a
plain `settings.json` hook can do this with no plugin at all.

## Decision
Own the whole pipeline in `~/.claude`, versioned in this repo.

`rules/adhd.md` is the single source of the output rules — shape plus the B2/C1 English level — and
has two consumers: the SessionStart hook loads it into the session prompt, and `adhd-rewrite.sh`
appends it to the few-shot wrapper in `adhd-rewrite-prompt.md` to build the local model's system
prompt. The rules are never copied.

`hooks/adhd-rewrite.sh` is the `MessageDisplay` hook: buffer the non-cumulative chunk deltas, act
only on the final chunk, skip messages under `ADHD_MIN_CHARS` prose characters, call
`$ADHD_OLLAMA/api/chat`, emit `displayContent`. Its one inviolable contract is **fail open** — no
`jq`, no `curl`, a dead server, a timeout, an empty or truncated completion must all leave the
original text on screen, which in `replace` mode means re-emitting the buffered original because the
intermediate chunks were already blanked. Only what is used is implemented: two modes, one provider,
no styles, no language switching, no markdown rewriting.

`skills/adhd/` and `hooks/adhd-ctl.sh` give `/adhd` a dashboard and the live overrides in `state/`,
which beat the frozen `ADHD_*` env. `hooks/adhd-probe.sh` checks the hook directly instead of a
versioned plugin path, and adds the fail-open case the old probe never had.

`claudish-to-english` is set to `false` in `enabledPlugins` — disabled, not uninstalled, so it stays
available as a fallback. This is the second skill in `~/.claude`, which ADR 0004 requires an ADR for.

## Consequences
The rules cannot drift, the probe cannot break on a plugin release, and every part of the pipeline
is readable and versioned here. Cost: upstream fixes and features no longer arrive for free, and the
`MessageDisplay` contract is now ours to keep in step with the CLI. `replace` mode blanks the screen
until the rewrite lands (~9 s warm on CPU-only `gemma4:e4b`, ~26 s cold), so a bug that loses the
final emit shows the user an empty answer — hence the fail-open probe as a standing check. A new
gitignored `state/` directory holds runtime flags. Re-enabling the plugin would put a second
`MessageDisplay` hook on the same messages.
