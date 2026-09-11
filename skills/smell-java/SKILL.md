---
name: smell-java
description: Rank refactoring candidates in a project by code-graph blast radius and name the Fowler refactoring for each, Java best practice first (sealed types, switch patterns, records, EnumMap, Spring strategy beans, @Transactional and N+1 rules) with short TypeScript, Groovy and Dart notes. Use when the user asks what to refactor, to find code smells, if/else or switch chains, deep nesting, duplicated code, long methods, God classes, speculative abstractions, "if-else hell", "co zrefaktorować", "znajdź smrody", or asks whether a conditional should become polymorphism, a strategy, a map lookup or guard clauses. Argument = a class, package, directory or file to scope the scan (nothing = whole project), plus optional --rigor advisory|conservative|standard|thorough. Writes one full refactoring plan to <project>/docs/plans/smell-java-<YYYY-MM-DD>.md (creation date in the name) and never touches project code. Not for reviewing a diff (/code-review) and not for applying fixes (/simplify, engineer).
---

# smell-java

One scan, one refactoring plan file, no code touched. The graph picks the files (a smell in a
hotspot is worth more than the same smell in dead code), `scripts/measure.sh` counts the
numbers, `scout` agents read the files against `references/catalogue.md` and
`references/java-modern.md` and judge only what a count cannot, the main loop merges into
`<project>/docs/plans/smell-java-<YYYY-MM-DD>.md`, dated by the day it was created. The plan is
the only file this skill writes; the user reviews it and runs each step through `engineer`. "No change needed" is a normal plan.

## 0. Arguments

`/smell-java [scope] [--rigor advisory|conservative|standard|thorough]`. Default rigor is
`conservative`. Resolve the word to numbers **before** spawning; scouts get the numbers:

| rigor | method lines | params | nesting | dup lines | chain arms | extra |
|---|---|---|---|---|---|---|
| `advisory` | >40 | >4 | ≥4 | ≥6 | ≥3 in ≥2 places | report only rows with callers ≥5 and effort ≤ `1 h`; no modernisation cluster |
| `conservative` | >40 | >4 | ≥4 | ≥6 | ≥3 in ≥2 places | modernisation as one cluster row when ≥3 items |
| `standard` | >30 | >3 | ≥3 | ≥5 | ≥3 in ≥2 places | cluster when ≥2; §5.1 speculative generality on |
| `thorough` | >20 | >3 | ≥3 | ≥5 | ≥2 in ≥3 places | every modernisation item a row; §5.4 lazy class on; §4.6 mapping from 2 hand-written mappers |

## 1. Stack preflight

Project root = `$PWD`, or the directory of the argument if it is an absolute path. Build one
**stack line** and pass it verbatim to every scout:

- Java release from `build.gradle*` (`languageVersion`, `sourceCompatibility`, `release`) or
  `pom.xml` (`maven.compiler.release`, `java.version`); Spring Boot version; Lombok, JPA/Hibernate,
  MapStruct, QueryDSL present or not (a `grep` of the build file is fine here). `MapStruct no`
  turns catalogue §4.6 into a "needs ADR" step, never a top row;
- `tests: yes|no` from `src/test` existing; the test command from
  `<project>/.claude/rules/project.md`; whether `<project>/.claude/rules/glossary.md` exists.

Example: `Java 21, Spring Boot 3.4, Lombok no, JPA yes, MapStruct no, tests yes (./gradlew test),
glossary no`.

Then `mcp__code-navigator__cg_map` with `projectPath`. No graph →
`bash ~/.claude/hooks/cg-sync.sh "<project>"` once, then re-check. Still nothing → report
`blocked`; do not grep-and-read a whole project. A language the graph does not index (not Java,
TypeScript, Groovy or Dart) → say so and scan only the argument scope, at most 5 files, with one
`scout`.

## 2. Scope: at most 12 files

- **No argument:** `cg_health(kind: "hotspots", limit: 15, projectPath)` inline. It returns two
  lists of bare symbol names, no paths. Take the **fan-out** list (complexity risk), drop every
  `*Test`, and keep the fan-in list only as a weight. Resolve each name to a path with one
  `cg_search(query: "<Name>.java", files: "true", projectPath)` (or one `find` by file name when
  the names are unambiguous); a bare method name like `create` is skipped, not guessed. Then
  `cg_health(kind: "coupling", symbol, projectPath)` for the top 3 only.
- **Argument given:** `cg_search(query: <argument>, projectPath)` for a class, or
  `cg_search(query: <argument>, files: "true", projectPath)` for a path; take at most 12 files.
  For a single class add `cg_related(symbol, direction: "in", projectPath)` so the scout knows
  the caller count.
- **`standard` / `thorough`:** add `cg_health(kind: "dead", type: "INTERFACE", projectPath)`;
  its result goes to the scouts as speculative-generality evidence (catalogue §5.1).

Result: absolute file paths with in-degree and line count, split into at most 3 groups of at
most 4, hotspots first. Drop test and generated files (`build/`, `target/`, `*MapperImpl`,
`Q*`) unless the argument names them. Say which files were not scanned.

Stale graph check: if any file in the list is newer than
`<project>/navigators/code/code-navigator.db`, run `bash ~/.claude/hooks/cg-sync.sh "<project>"`
before fanning out; a scout that finds a renamed class otherwise spends its budget on the sync.

**Measure pass (always, inline, one Bash call per group):**
`bash ~/.claude/skills/smell-java/scripts/measure.sh <absolute paths of the group> >
$CLAUDE_JOB_DIR/tmp/measure-<n>.txt` (use `/tmp/smell-java-measure-<n>.txt` outside a job). The
script counts per Java file: method length, parameter and boolean-flag count, nesting depth
(method body = 1), `!= null` checks, `switch` arm counts with the discriminator, `if/else-if`
chain arms, `instanceof` per variable, three-getter message chains, getter copies inside
`toX`/`fromX`/`map*` methods, `private final` dependency count, and the Spring, J1–J3 and
modernisation triggers of the two reference files. It is heuristic (brace and regex, no
parser: a lambda adds one nesting level, a nested `if` restarts the chain count), never edits,
and prints `SKIP` for non-Java files. The main loop reads nothing but the `FILE` lines; the
scout gets the path. A file the script marks `MISSING` is dropped from the group.

**Optional PMD pass (off unless `pmd` is on PATH):** spawn one `worker` with
`pmd check -d <files, comma-separated> -R category/java/design.xml -f text -r
$CLAUDE_JOB_DIR/tmp/pmd.txt`, then pass the `CyclomaticComplexity`, `NPathComplexity`,
`CognitiveComplexity`, `ExcessiveMethodLength` and `GodClass` lines to the scouts as counted
evidence. Never install PMD from this skill; PMD is not installed on this machine today.

## 3. Fan out: one `scout` per group

Spawn at most 3 `scout` agents in one message (read-only, pinned to `sonnet`, hold the `cg_*`
tools). Each prompt is the whole spec:

- `projectPath`, the stack line, the rigor table row as numbers, and the absolute paths of its
  group with each file's in-degree and line count;
- "your read budget for this task is the two reference files plus every file in your group;
  this replaces your usual three-file stop rule";
- "read `/home/kamil/.claude/skills/smell-java/references/catalogue.md` first; apply its
  thresholds (as overridden by the rigor numbers) and its §0 restraint rules — Rule of Three,
  utility exception, smell ≠ bug, indirection rule, stack-native first, skip list";
- "read `/home/kamil/.claude/skills/smell-java/references/java-modern.md` when the stack line
  says Spring or Java ≥ 16; propose only idioms at or below the project's release; for a Spring
  trigger name the plugin skill from its §2 table instead of describing the fix";
- "read `<project>/.claude/rules/glossary.md` first if it exists; every name you propose is a
  glossary term, never one of its `not:` synonyms";
- "read `<measure file>` first; its numbers are counted at the line they name: compare them
  with the rigor numbers, report them as-is and mark the finding `sure` once `cg_related`
  confirms the callers; verify a number in the file only when the script's heuristic can be
  wrong there (a lambda in a `nest` count, a nested `if` in an `IFCHAIN`); estimate (`likely`)
  only what the script cannot count — Rule of Three across files, feature envy, data class with
  logic elsewhere, §5 structure smells";
- any `cg_health dead` interfaces and PMD lines for its files;
- "for each finding add the plugin skill from catalogue §9 / java-modern §2 when one applies,
  as `plugin=<name>`; do not describe a fix shape the plugin owns";
- "for each candidate run `cg_related(symbol, direction: "in", projectPath)` once and report
  the caller count and how many callers are tests; mark `sure` only when you counted the number
  in the file and the graph confirmed the callers, else `likely`";
- the finding format below, "at most 6 findings, at most 30 lines, `no change needed` for a
  file with nothing above threshold, then one line with the largest sub-threshold value seen";
- "read only the files named and the measure file; no Grep sweeps; never edit".

Finding format, one line each:

```
<file>:<line> | <smell §> | <evidence: arms=N / depth=N / lines=N / dup=N lines with file:line / impls=N> | <refactoring, Fowler name + Java shape> | plugin=<spring-boot-4-skills name or none> | callers=N (tests=M) | <effort unit> | sure|likely
```

## 4. Merge: write the plan

The deliverable is one file, `<project>/docs/plans/smell-java-<YYYY-MM-DD>.md`, named with
today's date (`date +%F`); create `docs/plans/` if missing. A second run on the same day
overwrites that day's file; older plans stay as history and are never edited. It is the **full** plan: every finding above threshold
gets a step, not only the top rows. Shape:

```
# Refactoring plan: <project> (created <YYYY-MM-DD>, rigor <word>)
Stack: <stack line>
Scanned: N files (<list>); not scanned: <list or none>

## Ranked findings
| # | file:line | smell | refactoring | callers | effort |
(every finding, ranked; rows 1-5 are "do now"; effort carries `~` for a `likely` finding)

## Steps
### 1. <refactoring name> in <Class#method>
- Why: <smell, evidence numbers>
- Change: <the exact edit in two or three lines; glossary names only>
- Blast radius: callers=N (tests=M) from cg_related
- Verify: <test command from the stack line, narrowed to the class>
- Engineer prompt: one paste-ready paragraph (absolute path, the change, the verify command,
  "read <project>/.claude/rules/glossary.md first" when it exists, and "load
  spring-boot-4-skills:<name> first" when catalogue.md §9 or java-modern.md §2 names a plugin
  skill for the fix shape)
(one section per row, same order, all of them)

## Not extracted yet
Rule-of-Three cases with two copies, and sub-threshold values worth watching

## Needs Java N
idioms above the project's release, or "none"
```

Rank by `score = callers × (evidence ÷ threshold)`; `likely` sorts below `sure` at equal
score; ties → smaller effort first. A "modernisation" cluster is one row with its count and
one step listing every item. Nothing above threshold anywhere → the plan holds the stack line, the file
count, the rigor, the largest sub-threshold value seen, and "No change needed; next:
`--rigor standard`".

In chat, ADHD shape: first line = the plan path; second line = row 1 (file, smell, refactoring,
effort); then rows 1-5 of the table and the count of the rest; last line = the next action:
`open the plan and run step 1 through engineer`.

## Never

- Write anything except today's `<project>/docs/plans/smell-java-<YYYY-MM-DD>.md`; never edit project code, tests, other docs or an older plan.
- Apply a refactoring, even a 15-minute one; every change goes through `engineer` after the
  user picked a step.
- Spawn `engineer` or more than 3 `scout` agents; never a second round; a `worker` only for
  the optional PMD command.
- Propose a pattern below the resolved thresholds, an interface with one implementation, an
  idiom above the project's Java release, or a name that is a glossary `not:` synonym.
- Report a smell without `file:line` and a number, call a smell a bug, or report generated
  code, test code (unless scoped) or a file marked as being deleted.
- Grep-and-read when the graph is present.
