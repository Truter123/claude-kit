---
name: jira-task
description: 'Explain how to create a good Jira ticket and walk the user through doing it: which field goes where in the Create dialog, a paste-ready description template per issue type (task, story, bug, spike), how to write acceptance criteria that are actually testable, and a quality gate to check before hitting Create. Use whenever the user mentions writing, creating, filing or improving a Jira ticket, issue, task, story, bug, spike, epic or subtask, asks what to put in a ticket, asks for acceptance criteria, or says "załóż taska", "zrób ticket", "opisz to w Jirze" - even when Jira is not named but the output is clearly a backlog item.'
license: MIT
metadata:
  tags: "Jira, Tickets, Acceptance Criteria, ADHD, Agile, How-To"
  category: "workflow"
---

# jira-task

Teach the user how to create a ticket, and hand them something they can paste. Not a lecture — a filled-in draft plus the reason each part is there.

A ticket fails for four reasons: the assignee cannot tell why the work matters, nobody can tell when it is done, a required field blocks the Create button, or the body is a wall of prose so starting costs more than doing.

## How to behave

- **Draft first, explain second.** Show the filled-in ticket for their actual task, then a short "why each section" note. Never explain in the abstract when you have a real example in front of you.
- **One question maximum, at the end.** Make the reasonable call on every gap, list your assumptions under the draft, let them correct in one reply.
- **Give them the paste.** The description block goes in a fenced code block, ready to copy into Jira.
- **No status narration.** Do not say what you are about to do. Show the draft.

## The Create dialog, field by field

In Jira: **Create** button (or `c`) → then, top to bottom:

1. **Project** — where the work lives. If unsure, the project the code or team belongs to, not the one that reported it.
2. **Issue type** — `Task` (work to do), `Story` (user-visible value), `Bug` (something is broken), `Spike` (a question to answer). Pick by what "done" looks like, not by size.
3. **Summary** — 5–9 words, states the change, findable in a backlog of 200. No `[FEAT]` / `[NEW]` prefixes; the issue type field already says that. The exception is a prefix the project already uses on every ticket, such as `[BE]` / `[FE]` for a split backlog — match the neighbours, never invent one.
   - Bad: `Fix the thing on the dashboard`
   - Good: `Dashboard filter drops results after date-range change`
4. **Description** — the templates below.
5. **Priority / Components / Labels** — pick from the project's existing values. Never invent a near-duplicate label (`ux-research` vs `ux_research`); components drive the team's reporting, so pick, do not create.
6. **Parent / Epic link** — the umbrella this belongs under. Prefer a peer ticket plus a link (`relates to`, `blocks`) over a subtask, unless the team clearly uses subtasks.
7. **Assignee** — leave empty if it goes through refinement. Assigning early quietly skips the team's triage.
8. **Sprint / Story points** — usually set at refinement, not at creation. Leave them.

If Create is greyed out or errors, a required field is empty — the error names it. Jira projects each have their own required fields; there is no universal list.

## Description templates

Paste one, fill the brackets, delete what does not apply.

**Task**

```
### First step
[One concrete action to start: a path, endpoint, page, or command.
 e.g. Open src/api/orders.ts and read buildQuery()]

### Context
[Why this is on the board — what breaks or what is gained. 2-3 sentences.]

### The work
[What to do, plain language.]

### Acceptance criteria
* [ ] [True/false statement]
* [ ] [True/false statement]

### Out of scope
* [Adjacent thing a reader would assume is included and is not]
```

**Story** — same, but "The work" becomes:

```
### Story
When [situation], I want [capability], so that [outcome].
```

Job-story framing beats "As a <persona>" unless the persona actually changes the behaviour. Add `### Design` (link or TBD) and `### Technical considerations` — keep both *outside* acceptance criteria, so AC stays stable while the approach evolves.

**Bug** — repro steps come first, context drops to one line:

```
### Summary
[What is wrong and who it hits.]

### Steps to reproduce
# [Start from a named state — logged in as X, on page Y]
# [One action per step, no "and then"]

### Expected
### Actual
[Verbatim error text if there is one.]

### Environment
Version / build, browser / OS, URL, account.
No credentials, no tokens, no customer personal data — write [redacted].

### Impact
[Frequency, workaround, does it block release? This is what drives priority.]
```

**Spike** — a spike is done when a question is answered, not when code works:

```
### Question       [the single decision this unblocks]
### Timebox        [e.g. 2 days — a spike without a timebox is a project]
### Done when
* [ ] The question is answered in writing at [where]
* [ ] A recommendation exists with the trade-offs named
* [ ] Follow-up tickets created, or explicitly not needed
```

These are markdown, which is what both the Jira editor and the MCP tool want. If you are pasting by hand into an old wiki-markup project, swap `###` for `h3.` — but never send wiki markup through the MCP tool (see below).

## Acceptance criteria: the part people get wrong

Every line must be **true or false with no argument**. Use `Given / When / Then` when a flow or edge case matters, plain checkboxes otherwise. If a line cannot be phrased as testable, it is context — move it up into Context.

Rewrite these on sight:

- "Works on mobile" → "Renders without horizontal scroll at 375px width"
- "Is fast" → "Search returns in under 500ms p95 with 10k rows"
- "Handles errors" → "On a 500 from /orders, shows the retry banner and logs the request id"
- "User can log in" → "Given a valid magic link, when opened within 15 minutes, then the user lands on /dashboard authenticated"

## Keep it readable

1. **Under 300 words.** Longer means the work should be split — say so, offer to split, do not split unasked.
2. **Nothing important in prose.** Headings, bullets, checkboxes, numbered steps. A paragraph over four lines gets cut or converted.
3. **One bounded action per numbered step.** Never two "and then"s in a line.
4. **Cap every list at five.** Past five, split into must / nice-to-have.
5. **Concrete over vague, always.** `src/auth.ts:42`, `p95 under 300ms` — never "the auth code", never "fast".
6. **Open questions get their own line**, prefixed `OPEN:`. Never buried mid-sentence.

## Check before hitting Create

1. Someone outside the conversation can tell why the work matters.
2. The first step is concrete enough to start in under a minute.
3. Every acceptance criterion is true or false.
4. Nothing in the body is a guess presented as a fact.
5. It fits in one sprint.

## If a Jira tool is connected

If this session has Jira MCP tools (`mcp__*jira*`, `mcp__*atlassian*`) or `JIRA_URL` + `JIRA_EMAIL` + `JIRA_API_TOKEN` are set, offer to file it after the draft is approved — read the project's create metadata for required fields and allowed values first, then create and report the key and browse URL. Otherwise hand over the paste-ready block and say where it goes. Never invent an issue key or a Jira URL.

**Copy the field set from a sibling ticket, not from create metadata.** Create metadata lists only
what is *required*. A project's market, program, product-line and cost-code custom fields are
usually optional, so they never appear there — and a ticket without them drops out of the filters
the team actually reads. Before creating, `getJiraIssue` a recent ticket from the same project with
`fields: ["*all"]`, and carry over every non-null `customfield_*`, plus `components` and `priority`.
The field ids are per-project and not guessable; read them, do not remember them.

**File a pair as a pair.** When the work splits across two tickets (backend and frontend, service
and client), create both, then link them with `createIssueLink` using the link type the project's
existing pairs use — check a sibling's `issuelinks` rather than assuming `Blocks`. A dependency
written only in the description text is invisible on the board.

Before the first `createJiraIssue` / `editJiraIssue` call, read `references/mcp-formatting.md` in
this skill's directory. It holds the markdown-to-ADF traps (checkboxes and wiki links do not
survive, `renderedFields` lies) and the assignee/board-filter rule. They are verified against a real
project and they are not guessable, so a ticket filed without reading them shows literal `\[ \]` to
the reader.
