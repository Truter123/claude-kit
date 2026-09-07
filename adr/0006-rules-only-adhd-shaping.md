# 0006 — ADHD shaping by session rules only; drop the local rewrite

Status: accepted
Date: 2026-09-04
Supersedes: 0005

## Context
ADR 0005 built the `MessageDisplay` rewrite in-repo: `hooks/adhd-rewrite.sh` sent every finished
answer to local Ollama (`gemma4:e4b`, CPU only) and replaced it on screen, with `/adhd`,
`adhd-ctl.sh`, `adhd-probe.sh`, a two-shape prompt and fact guards. After a day of use the
rewrite cost more than it gave:

- 10–70 s per answer on CPU, 90 s timeouts under load, and `replace` mode blanks the screen
  until it lands.
- A 4B model flattened reviews into task lists, invented `Time: N/A`, dropped evidence sentences
  and code names; every fix was another prompt rule plus a shell guard (shape picker, length
  guard, code-span guard, echo strip).
- The main model already writes to `rules/adhd.md` when the rules are in the session prompt. A
  side-by-side check on a real CI answer showed the original was better than the rewrite.

## Decision
Keep one mechanism: the SessionStart hook in `settings.json` loads `rules/adhd.md` as
`additionalContext`, and the model that writes the answer shapes it. Everything else is deleted:
`hooks/adhd-rewrite.sh`, `hooks/adhd-rewrite-prompt.md`, `hooks/adhd-ctl.sh`,
`hooks/adhd-probe.sh`, `hooks/adhd-probe-review.txt`, `skills/adhd/`, `state/`,
`docs/adhd-rewrite.html`, the `ADHD_*` env, the `MessageDisplay` hook and its permission lines.
`statusline-adhd.sh` shows a fixed `🧠 ADHD` badge because the rules are always loaded.

`claudish-to-english` stays disabled in `enabledPlugins`; it is not a fallback any more.

## Consequences
No latency, no blank screen, no second model to keep honest, one fewer skill (back to one:
`refresh-docs`). The shaping now depends entirely on the main model following `rules/adhd.md`;
when an answer breaks shape the fix is the rules file, not a hook. "stop adhd mode" is confirmed in
one line and the rules stay loaded for the rest of that session — there is no `/adhd off` any more.
