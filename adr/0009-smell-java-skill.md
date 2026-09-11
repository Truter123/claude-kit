# 0009 — `/smell-java`: graph-ranked code-smell scan with Fowler refactorings, Java first

Status: accepted
Date: 2026-09-08
Plan: plans/use-research-skill-and-quizzical-mango.md

## Context
A `/research` run on 2026-09-08 found only generic prompt-pack skills for code-smell detection
(45ck/refactoring-code-smells-skills, mickeyyaya/refactoring-skills, FlorianBruniaux's
`design-patterns` example). None uses a code graph to decide *where* a smell matters, none is
Java/Spring aware, and none wraps a static analyser. Reddit's one clear lesson (the `solidifier`
skill, r/opencode 2026-07) is that agents over-apply patterns: every `if` becomes a strategy. The
built-in `/code-review` and `/simplify` work on a diff, not on a project, and `cg_health` ranks
hotspots but has no complexity or conditional-chain metric.

## Decision
Add one global skill, `skills/smell-java/`, read-only and chat-only. `SKILL.md` runs
`cg_health(kind: hotspots)` (or `cg_search` for an argument) to pick at most 15 files, fans out to
at most 3 `scout` agents that read `references/catalogue.md` and the project glossary, and merges
a ranked table (`file:line` · smell · Fowler refactoring · callers · effort) with one paste-ready
`engineer` prompt as the next action. `references/catalogue.md` is Java-first: thresholds per
smell, the modern-Java shape (sealed interface + exhaustive `switch`, `record` value objects,
`EnumMap`/`switch` expression lookups, Spring `Map<Kind, Handler>` strategy beans, guard clauses,
`Optional` at the boundary), a "modernisation" cluster list, one short section for TypeScript,
Groovy and Dart, and restraint rules first: three variants and an expected fourth before a
pattern, no one-implementation interface, smallest refactoring wins, "no change needed" is a
normal outcome. `evals/evals.json` holds three prompts for `skill-creator` benchmarking.

Amendments: ADR 0004's "one global skill" (two after ADR 0008) becomes three with ADRs
(`refresh-docs`, `research`, `smell-java`); `skills/commit/` and `skills/jira-task/` remain
untracked by any ADR. No agent, hook or `settings.json` change: `scout` was already spawnable from
the main loop with its pinned model, and the skill spawns nothing else.

## Consequences
A whole-project scan costs about three `scout` spawns at 45–50k tokens each (measured on
`next-crew-be`, 2026-09-08: the catalogue, four files and their `cg_related` calls), all outside
the main window; the main loop holds one `cg_health` result and three
30-line reports. Detection is model judgement against thresholds, not a metric: a scout can miss a
smell or misjudge an arm count, so every finding carries a number the user can check. The
thresholds and the restraint rules are prose with no hook enforcement, as in ADR 0001 and 0008.
The glossary gains **Smell-java** with `not: code review, lint, sonar`, so the skill is never confused
with the diff-based built-ins. The graph's Dart call binding (~67% of call sites) makes caller
counts there a lower bound; the catalogue's effort scale says so through the test-share rule.

## Amendment 2026-09-08 (v2): merge of thirteen existing skills
Thirteen public smell/refactoring skills were cloned and swept (45ck, mickeyyaya, hatlesswizard,
WomenDefiningAI, FlorianBruniaux, sethdford, solidifier, solid-skills, Santoshrt999 Java-Claude-
Skills, jabrena/plinth, decebals/claude-code-java, terenceallen/claude-code-setup;
myndharis/antigravity-skills is gone). None has detection code beyond a line-count watcher and
none wraps PMD, Sonar or OpenRewrite, so the graph-ranked, threshold-based, `file:line`-required
core stays. Merged in: a rigor dial `--rigor advisory|conservative|standard|thorough`
(solidifier) resolved to numbers before the scouts are spawned; a stack preflight line (Java
release, Spring Boot, Lombok, JPA, tests) so no idiom above the project's release is proposed
(plinth "verify language level"); restraint gates — Rule of Three, utility exception, smell ≠
bug, indirection rule, stack-native first, skip generated/test code (mickeyyaya, sethdford,
solidifier §2.20); the rest of Fowler's catalogue with graph evidence (speculative generality
via `cg_health dead`, divergent change via coupling, middle man, lazy class, refused bequest,
temporary field, inappropriate intimacy) and Martin's Java J1–J3; a second reference file
`references/java-modern.md` with Java 8–24 idioms and their minimum release plus Spring rules
(`@Transactional` self-invocation and placement, N+1, field injection, Lombok `@Data` on
entities, `@ControllerAdvice`, strategy beans start at three) taken from claude-code-java and
claude-code-setup; a `sure|likely` confidence mark shown as `~` on the effort cell. Rejected:
the 1–100 per-file score (unanchored), TDD and size enforcement (a skill cannot enforce, per
r/ClaudeAI 2026-01), the worktree parallel-fix pipeline (the skill stays read-only). An optional
PMD pass through one `worker` is described but off: PMD is not installed and the skill never
installs it.

## Amendment 2026-09-08 (v2.1): the deliverable is a plan file
The skill's output is one file in the project, `<project>/docs/plans/smell-java-<YYYY-MM-DD>.md` (dated by creation day; the full
plan: ranked table, one step per finding with the exact change, blast radius, verify command and a paste-ready `engineer`
prompt, a "later" list, a "needs Java N" list), overwritten per project. It never edits project
code, tests or docs and never applies a refactoring itself; the user reads the plan and runs a
step through `engineer`. This replaces "chat only" above; the chat answer is the plan path, row
1 and the table.

## Amendment 2026-09-08 (v2.2): no duplication of `spring-boot-4-skills`
An `explorer` comparison found 12 of the 14 Spring rules in `references/java-modern.md` §2 already
stated by the plugin (`transactional-patterns`, `spring-data-jpa`, `layered-architecture`,
`problem-details-rfc9457`, `configuration-properties`, `http-interface-clients`, `null-safety`,
`resilience-retry`), with no contradiction on Boot 4 / Framework 7 facts. §2 now holds only the
detection trigger per rule and the plugin skill that owns the fix; the engineer prompt in the
plan names that skill. Only the two rules the plugin lacks keep their full shape here: the
`switch`-over-enum → `Map<Kind, Handler>` strategy beans and the two-variant restraint. The
plugin has no smell detector of its own, so the split is: smell-java detects, the plugin fixes.
A second pass mapped the whole catalogue (not only Spring rules) to the plugin: `catalogue.md`
§9 lists the 16 smell → plugin-skill pairs (`domain-driven-design`, `rest-api-conventions`,
`layered-architecture`, `spring-modulith`, `hexagonal-architecture`, `null-safety`,
`spring-data-jpa`, `problem-details-rfc9457`, `configuration-properties`, `testing-pyramid`) and
the ten smells with no plugin coverage; a scout's finding carries `plugin=<name>` and the plan
step's engineer prompt loads it.
Catalogue §4.6 adds hand-written entity↔DTO mapping (≥3 `toX`/`fromX` methods, or ≥8 field
copies in one, or one type mapped by hand in ≥2 classes) → a MapStruct `@Mapper(componentModel =
"spring")` per aggregate with `unmappedTargetPolicy = ERROR`; the plugin has no MapStruct rule
(only a mapper port in `hexagonal-architecture`'s adapter example). When the stack line says
`MapStruct no` the step is marked "needs ADR" (new dependency) and never ranks in the top rows.

## Amendment 2026-09-09 (v2.3): counted evidence before judgement
A `/research` re-check on 2026-09-09 found nothing new besides the official SonarQube plugin
for Claude Code (real Sonar engine, scan-fix-rescan loop that edits code; considered, not
adopted: it breaks the plan-only contract). `spring-boot-4-skills` v1.3.0 still has no smell or
refactoring skill (zero hits for smell, refactor, Fowler, PMD, Sonar, cyclomatic). The
weakness named in Consequences — "detection is model judgement, a scout can misjudge an arm
count" — is closed for the countable smells: `scripts/measure.sh` + `measure.awk` (POSIX awk,
mawk-compatible, no parser) run inline from the main loop once per scout group and write per
file the method lengths, parameter and boolean-flag counts, nesting depth (body = 1), null
checks, `switch` arms with discriminator, `if/else-if` chain arms, `instanceof` per variable,
three-getter chains, getter copies in `toX`/`fromX`/`map*`, `private final` dependency count and
the Spring, J1–J3 and modernisation triggers. A scout compares those numbers with the rigor
row and marks them `sure`; it estimates (`likely`) only Rule of Three across files, feature
envy, data class and the §5 structure smells. Known heuristics: a lambda or anonymous class
adds one nesting level, a nested `if` restarts the surrounding chain count, text blocks are not
stripped, non-Java files print `SKIP`. Two fixtures under `evals/fixtures/` (`Smelly.java`,
`Edge.java`) are the regression check. The file cap stays 12 (SKILL.md), not the 15 written
above. The optional PMD pass is unchanged and still off.
