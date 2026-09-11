# Smell catalogue — Java first

Read this before scanning. Each smell has a **threshold** (below it: not a finding), the
**evidence** to report, and the **refactoring** by its Fowler name with the modern-Java shape.
The prompt's stack line names the Java release; an idiom that needs a newer one is not a
finding (see `java-modern.md`). The prompt's rigor line may override the numbers below; the
numbers here are the `conservative` default.

## 0. Restraint rules (read first, apply last)

1. A pattern needs **three or more variants and a reason to expect a fourth**. Two arms stay an
   `if`. Three arms that will never grow stay a `switch`.
2. **Never an interface with one implementation.** Never a factory for one constructor. Never a
   builder for three fields.
3. **Prefer the smallest refactoring** that removes the smell: guard clause before extract method,
   extract method before extract class, `switch` expression before polymorphism, `Map` lookup
   before a class hierarchy.
4. **"No change needed" is a normal outcome.** A file the graph ranked as a hotspot is not a
   finding by itself; the hotspot rank only says a finding there is worth more.
5. Every finding carries `file:line` and a number (arm count, depth, line count, duplicate span).
   No number, no finding.
6. Names in a proposed refactoring come from the project's glossary. A `not:` synonym is never
   proposed as a class or method name.
7. **Rule of Three.** Duplication is extracted at the third occurrence, not the second, unless
   the two copies already differ by a bug.
8. **Utility exception.** A `static` helper of ≤15 lines may keep a 5-arm `switch` or a
   3-deep `if`; it is read as a table.
9. **A smell is not a bug.** Never call a finding a bug; when the smell hides a likely defect,
   say "worth investigating" and give the line.
10. **Indirection rule.** If the refactoring adds more indirection than it removes complexity,
    do not propose it. One new class must delete at least one branch, one copy or one
    responsibility somewhere else.
11. **Stack-native first.** A JDK or Spring feature (sealed `switch`, `record`,
    `@ControllerAdvice`, `@ConfigurationProperties`) beats a hand-written pattern.
12. **Skip:** generated code (`build/`, `target/`, `*MapperImpl`, `Q*` querydsl, `*_` JPA
    metamodel), test code unless the scope names it, and a file the prompt marks as
    deprecated or being deleted.

## 1. Conditional chains

### 1.1 Same discriminator in several places → Replace Conditional with Polymorphism
- **Threshold:** `switch` or `if/else-if` on the same field, enum or type (`instanceof`) with
  ≥3 arms, appearing in ≥2 methods or classes.
- **Evidence:** discriminator name, arm count, the `file:line` of each chain.
- **Java shape:** a `sealed interface` with one `record`/`final class` per variant, behaviour
  moved into the variants; or, when the variants are data-only and the behaviour lives in
  services, keep the data as a sealed hierarchy and dispatch with a `switch` expression with
  pattern matching (exhaustive, no `default`). Sealed + exhaustive switch is preferred over a
  visitor and over an abstract class.
- **Spring shape:** a `Map<Kind, Handler>` built from injected `List<Handler>` where each
  `Handler` declares `supports()` or `kind()`. One bean per variant. Do not add
  `@Component` classes for two cases.
- **Not a finding:** one chain in one place (see 1.2); a chain over an external protocol value that
  is decoded once at the boundary.

### 1.2 One chain that only maps input to output → Replace Conditional with Lookup
- **Threshold:** ≥3 arms, each arm returns or assigns a value and nothing else.
- **Java shape:** `switch` expression with arrows (`case A -> …`), or an `EnumMap`/
  `Map.of(...)` constant when the mapping is data. An `enum` with a field or an abstract method
  when the mapping belongs to the enum itself.
- **Not a finding:** a two-arm ternary.

### 1.3 Nested conditionals that guard a happy path → Replace Nested Conditional with Guard Clauses
- **Threshold:** nesting depth ≥3 where the inner block is the main work and the outer `if`s
  only validate.
- **Java shape:** early `return` / `throw` per validation, happy path at indentation level one.
  Validation of arguments goes to `Objects.requireNonNull`, a `record` compact constructor, or
  Bean Validation (`@Valid`) at the controller boundary — not to a service method body.

### 1.4 Type checks → Replace Type Code with Subclasses / pattern matching
- **Threshold:** ≥2 `instanceof` checks on the same value, or `getClass()` comparisons, or a
  `String`/`int` "type" field with a `switch` on it.
- **Java shape:** `if (x instanceof Foo f)` pattern binding for one check; `switch (x) { case Foo f
  -> … }` over a sealed type for several; a sealed hierarchy instead of a type code field.

### 1.5 Null chains → Introduce Null Object / Optional at the boundary
- **Threshold:** ≥3 `!= null` checks on the same chain (`a.getB().getC()`), or `null` returned
  from a public method that callers test.
- **Java shape:** return `Optional<T>` from repositories and finders, `orElseThrow` at the use
  site; a null object for a "missing" strategy; never `Optional` as a field or a parameter.

## 2. Nesting and length

### 2.1 Deep nesting → Extract Method / Guard Clauses / Replace Loop with Pipeline
- **Threshold:** depth ≥4 (method body = 1), or a loop with an `if` that only filters.
- **Java shape:** a `Stream` pipeline (`filter`/`map`/`collect`) when the loop builds a
  collection or an aggregate; an extracted method named for the intent when it does work; guard
  clauses for the validation layers. Do not stream a loop that has side effects or early exit.

### 2.2 Long method → Extract Method / Decompose Conditional
- **Threshold:** >40 lines, or a comment that names a section ("// validate", "// persist").
- **Evidence:** line count and the section comments.
- **Java shape:** one private method per named section; the public method reads as the flow.

### 2.3 Long parameter list → Introduce Parameter Object
- **Threshold:** >4 parameters, or ≥2 methods sharing the same 3 parameters (a data clump).
- **Java shape:** a `record` named for the concept (glossary term), validated in its compact
  constructor. Flag `boolean` parameters separately: two boolean flags → two methods or an enum.

### 2.4 Large class → Extract Class
- **Threshold:** >400 lines, or a `@Service` with ≥6 injected dependencies, or a class in the top
  3 of `cg_health(kind: hotspots)` whose method names span two nouns.
- **Evidence:** line count, dependency count, the two nouns.
- **Java shape:** one class per noun; a constructor-injected Spring bean each. Never a static
  utility class for domain logic.

## 3. Duplication

### 3.1 Same code in two places → Extract Method / Pull Up Method
- **Threshold:** ≥6 identical or near-identical lines (differing only in a literal or a name) in
  two files, or two methods in one class that differ in one expression. Rule of Three applies:
  two copies are a finding only when they already diverged (one got a fix the other did not).
- **Evidence:** both `file:line` ranges and the one varying expression.
- **Java shape:** one method with the varying part as a parameter (a value, an `enum`, or a
  `Function`/`Predicate`); for sibling classes, pull up to the sealed parent or a shared
  component. Form Template Method only when the shared skeleton has ≥3 varying steps.

### 3.2 Same `try/catch` or logging block repeated → Extract wrapper
- **Threshold:** the same catch-and-translate block in ≥3 methods.
- **Java / Spring shape:** `@ControllerAdvice` for HTTP translation, an `@Aspect` or a
  `Function`-taking helper for the rest, `@Transactional` instead of manual transaction blocks.

## 4. Data and responsibility

### 4.1 Feature envy → Move Method
- **Threshold:** a method calls ≥3 getters of one other object and ≤1 of its own class.
- **Java shape:** move the method onto the object it reads; keep `record` accessors, add
  behaviour to the record or the aggregate. Confirm with `cg_related(direction: "in")` that the
  callers are few before moving.

### 4.2 Primitive obsession → Replace Primitive with Object
- **Threshold:** the same `String`/`long`/`BigDecimal` meaning (an id, money, an email) passed
  through ≥3 signatures, or validated in ≥2 places.
- **Java shape:** a `record` value object with validation in the compact constructor, named by
  the glossary term (`OrderId`, `Money`). Map it with a JPA `@Embeddable` or an
  `AttributeConverter`; do not leak it into DTOs as a nested object unless the API contract wants
  it.

### 4.3 Data class with logic elsewhere → Move behaviour into the aggregate
- **Threshold:** an entity or DTO with only getters/setters whose invariants are enforced in a
  service (`if (order.getStatus() != …) throw`) in ≥2 places.
- **Java shape:** the check becomes a method on the aggregate (`order.cancel()`), throwing a
  domain exception; the service calls it. Setters that let an invariant break are removed.

### 4.4 Message chains → Hide Delegate
- **Threshold:** `a.getB().getC().getD()` in ≥2 places.
- **Java shape:** one method on `a` that answers the question; or a query in the repository.

### 4.5 Shotgun surgery (from the graph)
- **Threshold:** `cg_health(kind: coupling, symbol)` shows ≥3 files that always change together
  and share no package.
- **Refactoring:** Move Method / Inline Class toward the file that owns the concept. Report as
  "structural", not as a code edit; the main loop decides.

### 4.6 Hand-written mapping code → MapStruct mapper
- **Threshold:** ≥3 hand-written mapping methods (`toResponse`, `toDto`, `toEntity`,
  `fromRequest`, `map*`) across the scanned files, or one mapping method with ≥8 field copies
  (`builder().a(x.getA())…` or `new Dto(x.getA(), x.getB(), …)`), or the same entity mapped by
  hand in ≥2 classes.
- **Evidence:** method names with `file:line`, field-copy count per method, how many classes map
  the same type; whether the stack line says `MapStruct yes`.
- **Java shape:** one `@Mapper(componentModel = "spring")` interface per aggregate or per
  bounded context (`OrderMapper`), generated at compile time; `@Mapping` only for renamed or
  derived fields; nested objects via `uses = {…}`; `record` DTOs map without setters;
  `unmappedTargetPolicy = ReportingPolicy.ERROR` so a new field cannot be silently dropped.
  Inject the mapper; never call `Mappers.getMapper` in Spring code.
- **Spring / hexagonal shape:** the mapper lives with the adapter that needs it (a REST mapper
  in the controller package, a persistence mapper next to the JPA entity); the domain never
  imports it.
- **Restraint:** `MapStruct no` in the stack line means a new dependency, so the finding is a
  plan step marked "needs ADR: add `org.mapstruct:mapstruct` + annotation processor (and
  `lombok-mapstruct-binding` when Lombok is present)"; at `advisory` and `conservative` rigor
  it goes to the plan's later list, never to the top rows. A mapping of ≤4 fields stays a
  `record` static factory (`OrderResponse.from(order)`). Mapping that applies business rules
  (a computed status, a money formula) is not a mapper concern: keep that in the domain and map
  the result. Generated `*MapperImpl` is skipped (§0.12).

## 5. Structure smells the graph can see

### 5.1 Speculative generality → Collapse Hierarchy / Inline Class / Remove Parameter
- **Threshold:** an interface or abstract class with exactly 1 implementation and no caller
  outside its own package (`cg_health(kind: "dead", type: "INTERFACE")` or
  `cg_related(direction: "in")` = 1); a `Base*`/`Abstract*` class with one child; a parameter no
  body reads; a hook method nobody overrides.
- **Evidence:** the type, its implementation count, the caller count.
- **Not a finding:** an interface that a test double implements *and* the project's `project.md`
  or ADRs name it as a port; a public API of a library module.

### 5.2 Divergent change → Extract Class
- **Threshold:** `cg_health(kind: "coupling", symbol)` shows one class changing together with
  ≥3 files that belong to unrelated features or packages.
- **Evidence:** the class and the three co-change files.

### 5.3 Middle man → Remove Middle Man / Inline
- **Threshold:** ≥50 % of a class's methods are one-line delegations to the same field
  (`cg_related(direction: "out", depth: 1)` shows one target for most methods).
- **Not a finding:** a facade over an external system, an anti-corruption layer named in the
  docs, a Spring `@Service` that adds a transaction boundary.

### 5.4 Lazy class → Inline Class (`thorough` rigor only)
- **Threshold:** a class ≤20 lines with ≤1 caller that adds no invariant and no name the
  glossary knows.

### 5.5 Refused bequest → Replace Inheritance with Delegation / sealed hierarchy
- **Threshold:** a subclass overriding a parent method to throw `UnsupportedOperationException`,
  or using ≤20 % of the inherited methods.

### 5.6 Temporary field → local variable / parameter object
- **Threshold:** a field written in one method and read in exactly one other, `null` the rest
  of the time.

### 5.7 Inappropriate intimacy → Move Method / Extract Class
- **Threshold:** two classes calling each other's non-public-API (package-private, protected,
  getters of internals) ≥3 times in each direction (`cg_related(direction: "both")`).

## 6. Java-specific (Martin, *Clean Code* J1–J3)

- **J1 Long import lists / wildcards:** ≥2 wildcard imports in a file, or a class importing
  ≥5 classes from one other package that is not its own → the class probably belongs there
  (Move Class) or the package is a utility bag (Extract Package). Cluster item, not a row.
- **J2 Constants inherited through an interface** (`implements Constants`) → `static import`
  or an `enum`.
- **J3 Constant groups as `public static final int`/`String`** (`STATUS_NEW = 1`, `STATUS_DONE =
  2`) → an `enum`, with the behaviour that switches on them moved onto it (see 1.2).

## 7. Effort scale

Report effort in these units only: `15 min` (one method, tests exist), `1 h` (one class, tests
exist), `half a day` (new hierarchy or value object across ≤5 callers), `a day+` (≥6 callers or
no tests). Multiply by two when `cg_related(direction: "in")` shows the callers are mostly tests
that would need rewriting, and when the stack line says `tests: no`.

## 8. Confidence

Mark a finding `sure` when the number came from the measure file (`scripts/measure.sh`) or was
counted in the file **and** `cg_related` confirmed the callers; `likely` otherwise (graph miss,
Dart call binding, a non-Java file the script skipped, a count estimated from a skim). A
`likely` finding still needs its `file:line`. The script counts §1.1–1.5, §2.1–2.4, §4.4, §4.6,
J1–J3, the Spring triggers and the modernisation items; §3, §4.1–4.3 and §5 stay judgement.

## 9. Fix shapes owned by `spring-boot-4-skills`

The plan's engineer prompt says "load `spring-boot-4-skills:<name>` first" when the row below
names one; the catalogue then does not describe that shape twice. A smell with no row here is
fixed from its own section above. Checked against the plugin on 2026-09-08.

| Smell § | Plugin skill | What it owns |
|---|---|---|
| 1.1 conditional → polymorphism, when the behaviour belongs on a domain object | `domain-driven-design` | behaviour on the aggregate, never in a service `switch` |
| 1.3 guard clauses for argument validation | `rest-api-conventions` | Bean Validation on request records at the controller boundary |
| 1.3 guard clauses for invariants | `domain-driven-design` | the invariant check as an aggregate method |
| 1.5 null chains | `null-safety`, `spring-data-jpa` | JSpecify annotations; `Optional` from repositories |
| 2.3 parameter object for a request or paging | `rest-api-conventions` | request/response `record` DTOs, `Pageable` |
| 2.3 parameter object for a command | `domain-driven-design` | `record` commands |
| 2.4 large service | `layered-architecture` | one application service per aggregate root |
| 2.4 large aggregate | `domain-driven-design` | aggregate size, split at 3–4 child entities |
| 3.2 repeated catch-and-translate | `problem-details-rfc9457` | `@ControllerAdvice` extending `ResponseEntityExceptionHandler` |
| 4.1 feature envy, 4.3 data class, 4.4 message chains | `domain-driven-design` | rich model, root-only access to children, static factories |
| 4.2 primitive obsession | `domain-driven-design`, `spring-data-jpa` | `record` value object; `@Embeddable` / `AttributeConverter` mapping |
| 4.6 hand-written mapping → MapStruct | none — `hexagonal-architecture` only shows a mapper port in its adapter example; the MapStruct shape is §4.6 here |
| 4.5 shotgun surgery, 5.2 divergent change, 5.7 inappropriate intimacy | `spring-modulith`, `hexagonal-architecture` | module boundaries and visibility; ports and adapters |
| 5.1 speculative generality — the exception | `hexagonal-architecture` | an interface that is a declared port is *not* a finding even with one adapter |
| 6 J2/J3 constants | `domain-driven-design` | `enum` with behaviour instead of constant interfaces or `static final` groups |
| 6 J3 constants that are configuration | `configuration-properties` | a `@ConfigurationProperties` record |
| any step whose verify line says `tests: no` | `testing-pyramid` | the test to write before the refactoring |

No plugin coverage (fixed from this file only): 1.2 lookup, 1.4 type checks, 2.1 nesting,
2.2 long method, 3.1 duplication, 5.3 middle man, 5.4 lazy class, 5.5 refused bequest,
5.6 temporary field, J1 imports.
