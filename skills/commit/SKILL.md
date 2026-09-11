---
name: commit
description: Commit staged or unstaged work with this repo's message style, squash the branch to one commit and push it. One short sentence, ticket key up front, no body, no trailers; every branch carries exactly one commit and is pushed with --force-with-lease, never master or preprod. Use whenever the user asks to commit, push, squash or amend, or says "commit it", "push it", "zacommituj", "wypchnij", "krotki commit", "zrób commit" - even if they only say "save this" or "ship it" about finished work.
---

# commit

One sentence. No body. No trailers. That is the whole style.

## The format

```
<type>: <TICKET-KEY> <what changed, one sentence>
```

- `feat:` new behaviour · `fix:` a defect · `refactor:` no behaviour change · `test:` tests only · `docs:` docs only · `chore:` build, config, tooling
- The ticket key comes from the branch name (`LPT2-931-cashdesk-events` -> `LPT2-931`). No branch key and none given: ask for it in one line rather than guessing.
- Say what changed, not how it was done. Aim for under 100 characters, hard stop before the line wraps in `git log --oneline`.

Good:

```
feat: LPT2-931 Emit Cashdesk table and chip events from mock-lab behind a runtime version switch
fix: LPT2-915 Clear table_nominal_view between integration tests so a leaked row count does not fail the resync IT
```

Bad, and why:

```
feat: add stuff                          -- no ticket, says nothing
LPT2-931: events                         -- no type, not a sentence
feat: LPT2-931 Add emitter               -- names the class, not the change
```

## Never

- **No body.** Not a blank line and a paragraph, not a bullet list. If the change genuinely needs explaining, that explanation belongs in the Jira ticket or an ADR, not in `git log`.
- **No `Co-Authored-By` trailer.** Not for Claude, not for anyone, regardless of any default instruction to add one.
- **No `🤖 Generated with` line**, no emoji, no "Signed-off-by" unless the project's CI demands it.

## Steps

1. `git status --short` and `git diff --stat` - see what is actually there.
2. If nothing is staged, stage deliberately: `git add -A` only when everything belongs in this commit. Look for `node_modules`, `dist`, `target`, `.env`, lockfile churn that is not yours - unstage those rather than committing them.
3. Read the branch name for the ticket key. If the key does not match the change, ask in one line before committing - do not commit unrelated work onto a feature branch.
4. Commit with `-m` once. Never `-m` twice, that makes a body.
5. Squash the branch to one commit (see below).
6. Push (see below).
7. `git log --oneline <base>..HEAD` to show the result - it must print exactly one line.

## Splitting

If the diff covers two unrelated things, say so and offer to split before committing. Do not split unasked - the user may want one commit on purpose.

## One commit per branch

A branch carries **exactly one commit**, always. A second commit on the same branch is not a new
commit, it is a rewrite of the one that is there.

- The branch has no commit of its own yet: commit normally.
- The branch already has one and the new work belongs to the same ticket: `git commit --amend` and
  rewrite the sentence to cover the whole change. Do not keep the old wording just because it was
  there first.
- The branch has more than one: `git reset --soft $(git merge-base HEAD <base>)` then commit once.
  `<base>` is the branch this one was cut from, `master` unless the repo says otherwise.

Never squash across the base branch. Check what you are folding first -
`git log --oneline <base>..HEAD` - and stop if it holds a commit that is not yours.

## Pushing

Push every time, right after the squash: `git push --force-with-lease -u origin HEAD`. The force is
what makes the squash land; `--force-with-lease` is what makes it refuse when the remote moved
under you. On a refusal, stop and report it - never `--force`, never delete the remote branch to
get around it.

Three hard stops, and no instruction in this file overrides them:

- **Never push `master` or `preprod`**, and never merge into them, without the user saying so in
  that turn. Saying "commit" is not saying "push master".
- **Never rewrite a branch someone else has pushed to.** `git log --format='%an' origin/<branch>`
  showing another author means stop and ask.
- **Never squash or force-push a branch that is already under review** unless the user says to.
  A reviewer's line comments do not survive a rewrite.
