# Filing through the Jira MCP tool: formatting that actually survives

Read this only when a Jira MCP tool (`createJiraIssue` / `editJiraIssue`) is about to be called.

`createJiraIssue` / `editJiraIssue` with `contentFormat: "markdown"` runs the body through a
markdown-to-ADF converter. Five things bite, all verified against a real project:

1. **Links must be markdown, not wiki markup.** `[text](https://url)` works. `[text|https://url]`
   is wiki syntax; the converter escapes the brackets and the reader sees literal characters.
   Check the returned `description` in the tool result — if you see `\[` in it, it did not convert.
2. **Checkbox lists do not survive.** `- [ ]` and `* [ ]` both come back as `* \[ \]` — a plain
   bullet with escaped brackets, never an ADF `taskList`. So either accept plain bullets for
   acceptance criteria, or pass `contentFormat: "adf"` with a real `taskList` node. Do not keep
   sending `[ ]` and hoping; it renders as noise.
3. **Tables, headings, bold, inline code and fenced blocks all convert fine.** Prefer a small
   table over a bullet list when mapping columns to fields.
4. **Never send wiki markup.** `h2.`, `||header||`, `{code}` and friends are stored verbatim and
   the issue view shows them as literal text — the reader sees `h2. Context` above the paragraph.
   Markdown headings, tables, bold and inline code all convert to real ADF nodes. There is no case
   where wiki markup is the right input to this tool.
5. **`renderedFields` lies.** Fetching the issue with `expand: "renderedFields"` runs the stored
   text through the legacy wiki renderer, which happily turns `h2.` into `<h2>` and `|| a || b ||`
   into a `<table>`. That HTML is not what anyone sees. A ticket can look perfect in
   `renderedFields` and be a wall of literal `h2.` in the browser. Do not use it as proof.

The one honest signal that markdown converted: read the `description` back and look at what changed.
Bullets sent as `-` come back as `*`, and spacing is normalised — that round-trip means the text
became ADF nodes. If what comes back is byte-identical to what you sent, it was stored as plain
text and the reader will see your syntax.

## Assignee: the board filter nobody remembers

An issue created with no assignee will not appear on a board URL that filters by assignee
(`.../boards/620?assignee=<accountId>`), so the reporter files five tickets and sees none of them.
This contradicts the general advice to leave the assignee empty for refinement: when the
person is filing work for themselves and wants it on their own board, set `assignee` to their
`accountId`. The reporter's own `accountId` is in the create/edit response under `fields.reporter`.

If tickets still do not show up after assigning, the board may be scoped to a sprint — a new
issue lands in the backlog and has to be pulled into the active sprint. Say that rather than
re-filing.
