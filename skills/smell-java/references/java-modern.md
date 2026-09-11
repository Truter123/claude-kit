# Modern Java and Spring — idioms with their minimum release

Apply an idiom **only at or above the release named in the stack line** of the prompt. A
proposal that needs a newer release than the project builds with is not a finding; say "needs
Java N" once at the end instead. These are the "modernisation" items: at `conservative` rigor
they are one cluster row when ≥3 occur, at `thorough` each is a row.

## 1. Language idioms

| Idiom | Min | Replaces | When not |
|---|---|---|---|
| `record` | 16 | DTO / value class with fields, ctor, getters, `equals`/`hashCode` | a JPA entity (needs a no-arg ctor and mutable id); a class with behaviour that mutates |
| text block `"""` | 15 | concatenated multi-line SQL, JSON, HTML | a one-line string |
| `String.formatted` | 15 | `String.format(...)` on a literal | log calls (use the logger's `{}` placeholders) |
| pattern `instanceof` (`x instanceof Foo f`) | 16 | check-then-cast pairs | — |
| `sealed interface` / `permits` | 17 | an abstract base whose subclasses are a closed set; a "type" enum with a `switch` in every service | an open extension point (plugins, other modules subclass it) |
| `switch` expression with arrows | 14 | `switch` statement with `break` and a result variable | a `switch` whose arms have side effects and no result |
| pattern `switch` + record patterns (`case Circle(var r) ->`) | 21 | `instanceof` ladders over a sealed type | fewer than 3 variants |
| exhaustive `switch`, no `default` | 21 | `default: throw new IllegalStateException` on an enum or sealed type | a `switch` over `int`/`String` |
| sequenced collections `getFirst()`/`getLast()`/`reversed()` | 21 | `list.get(0)`, `list.get(list.size()-1)`, `Collections.reverse` | — |
| virtual threads (`Executors.newVirtualThreadPerTaskExecutor`, `spring.threads.virtual.enabled`) | 21 | a bounded platform-thread pool used only for blocking I/O | CPU-bound work; code that holds a `synchronized` block around I/O (pins the carrier, fixed in 24) |
| unnamed variable `_` | 22 | unused lambda / catch / pattern variables named `ignored`, `e`, `unused` | — |
| Stream Gatherers (`Stream.gather`) | 24 | hand-written windowing / folding loops over a stream | anything a plain `collect` does; refer to the official `java.util.stream.Gatherers` docs, do not invent a gatherer |
| `Optional` idioms: `map`/`flatMap`/`orElseThrow`/`ifPresentOrElse` | 9 | `isPresent()` + `get()`, `Optional` field or parameter | `Optional` as a field, a parameter or a collection element (never) |
| `java.time` + injected `Clock` | 8 | `new Date()`, `Calendar`, `System.currentTimeMillis()` for business time | — |
| `List.of` / `Map.of` / `Stream.toList()` | 9 / 16 | `Arrays.asList`, `Collections.unmodifiableList(new ArrayList<>())`, `collect(Collectors.toList())` | a list that must stay mutable |
| enhanced `for` / streams | 8 | index loops that only read | loops that need the index or early `break` with side effects |
| `var` for obvious right-hand sides | 10 | `Map<String, List<Order>> m = new HashMap<>()` | a right-hand side whose type is not visible (`var x = service.load()`) |

The fix shape for records as DTOs, `Optional` from repositories and nullability is also in
`spring-boot-4-skills:layered-architecture`, `spring-data-jpa` and `null-safety`; the table above
only says when the idiom applies.

Clustered items that are style, not idiom (report only inside the cluster, never as a row):
`StringBuffer` → `StringBuilder`; raw types; `Optional.get()`; returning `null` for a collection
→ `List.of()`; hand-written `equals`/`hashCode` on a data holder → `record`; wildcard imports.

## 2. Spring rules: detect here, fix shape in `spring-boot-4-skills`

The plugin `spring-boot-4-skills` already states the correct shape for most Spring rules; this
file does not repeat it. A scout reports the **trigger** below with `file:line`; the plan's
engineer prompt names the plugin skill to load for the fix. Every trigger is a finding at every
rigor level when the stack line says Spring; threshold is one occurrence unless stated.

| Trigger (what the scout looks for) | Fix lives in |
|---|---|
| `@Transactional` on a `private` method, or called from another method of the same bean (self-invocation); same for `@Async`, `@Cacheable`, `@Retryable` | `spring-boot-4-skills:transactional-patterns` (self-invocation, `readOnly`), `resilience-retry` for `@Retryable` |
| `@Transactional` on a `@RestController` | `spring-boot-4-skills:layered-architecture` |
| repository or `EntityManager` call, or lazy association access, inside a loop over entities (N+1); confirm the callee with `cg_related(out)` | `spring-boot-4-skills:spring-data-jpa` (`JOIN FETCH`, `@EntityGraph`) |
| `@Autowired` on a field; `new` of a `@Service`/`@Component` inside a bean | `spring-boot-4-skills:layered-architecture` (constructor injection) |
| Lombok `@Data` / `@EqualsAndHashCode` / broad `@Setter` on a JPA `@Entity`; public setters for every entity field | `spring-boot-4-skills:spring-data-jpa` (behaviour methods, static factories) |
| `try/catch` in a service or controller that builds `ResponseEntity` / status codes | `spring-boot-4-skills:problem-details-rfc9457` (`@ControllerAdvice`) |
| a rule, a calculation or a repository call inside a controller method | `spring-boot-4-skills:layered-architecture` |
| `@Value("${…}")` for one prefix spread over ≥3 beans | `spring-boot-4-skills:configuration-properties` |
| `RestTemplate` in new code | `spring-boot-4-skills:http-interface-clients` (`RestClient`, `@HttpExchange`) |
| `null` returned or accepted without a nullability annotation on a public API | `spring-boot-4-skills:null-safety` (JSpecify) |

Rules the plugin does not have (full shape here):

| Rule | Evidence | Refactoring |
|---|---|---|
| `switch` on an enum inside a `@Service` with ≥3 arms that each call another bean, in ≥2 places | the `switch` sites | `Map<Kind, Handler>` built from an injected `List<Handler>`; each handler declares `kind()`; one bean per variant |
| `@Component` per variant when there are only two variants | two trivial classes implementing one interface | restraint: keep a plain `if`; strategy beans start at three |

## 3. Other stacks (short)

- **TypeScript:** ≥3-arm `switch` on a string tag → discriminated union with an exhaustive
  `switch` and a `never` check; prefer that over a class hierarchy for data variants. Data-only
  mapping → `Record<Kind, …>` const. Guard clauses and early `return` as in Java. Nested
  callbacks/`then` chains ≥3 → `async/await`.
- **Groovy:** ≥3-arm `switch` → `Map` of closures keyed by the discriminator; `?.` and `?:`
  replace null chains; Spock data tables replace duplicated test bodies.
- **Dart:** ≥3 variants → `sealed class` with a `switch` expression (Dart 3 patterns) before an
  abstract class; `if (x case Foo f)`; `Map` constant for data mappings; collection `if`/`for`
  and `where`/`map` for filter loops.
