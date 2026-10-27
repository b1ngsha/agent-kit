# Coding Standards

How this service is written where no linter decides. Authors apply every rule
while writing; a review applies every rule to the diff. A rule is Hard unless under a Judgement label:

- **Hard**: a breach is a violation. Cite the file and section that state the rule.
- **Judgement**: report it as "possible …" with the reason, and let the author
  decide.

A **Judgement** label covers the rest of its section. A **Smell baseline
override** names the review smell the section replaces; it adds no rule.

## Owned elsewhere

These documents own their topic. Apply them as written.

| Topic | Owner |
| --- | --- |
| Go tests | `docs/standards/testing.md` |
| Schema and migrations, when present | `docs/standards/database.md` |
| OpenAPI contracts, when present | `docs/standards/api-contract.md` |
| Records: behavior or contract changes, new ADRs and documents | `docs/standards/records.md` |
| CI jobs, scripts, and runtime dependencies | `docs/standards/repo-maintenance.md` |

Formatting (`gofmt`) and every rule enabled in `.golangci.yml` belong to the
tools. `make fmt`, `make lint`, and `make test` run them.
Review accepts their output as final. A rule that becomes mechanically
checkable moves into a tool and leaves its document.

**Hard.** A suppression (`//nolint:<linter> // <reason>` or
`oxlint-disable-next-line <rule> -- <reason>`) states why the finding is false
at that line. A suppression, exclusion, or test-only branch that silences a
true finding so CI passes is a violation; fix the code instead. The one
exception is a new rule's baseline: the commit that enables the rule lists,
by path, the files it already breaks, and later commits only delete entries.

Where every source is silent, match the surrounding code. A change made only
to meet a standard keeps behavior identical and lands in its own commit,
apart from feature or fix work.

## Placement and extraction

Code **colocates**: an expression stays at its call site until the third
production occurrence of the same decision (the Rule of Three) shows which
part the callers share, so each layer a reader traces pays for itself.

**Hard.**

- A helper starts unexported, in the file of its callers. It moves outward
  one step at a time (file, then package, then a shared package) when a
  caller in the next scope needs it. A symbol moves together with its tests.
- A second file that needs a private helper's decision imports the moved
  helper. Before adding a helper, search the tree for one that already
  decides the same thing and call it. A copy under another name, a shorter
  one, or one written inline at the call site is still a copy.
- A package is named for what it provides. Shared code joins a package
  with that kind of name.
- One business rule (a validation, a state transition, a limit) has one
  source: the helper born at the third production call site. A test drives
  one of those sites.
- A repeated value (a literal, a lookup table, a key list) is one fact. The
  second file that needs it names it: naming adds no parameter and no branch,
  and two copies drift.
- A value that several callers share (a fallback message, a default, a limit,
  an error code) is held once: as a configured default where the API
  supports it, otherwise as a named constant each caller passes.
- A function, type, file, or test helper that only forwards to another,
  adding no decision, is a **pass-through** and is inlined, however many
  callers it has.

**Judgement.**

- A name earns a helper, even after the third caller, only when it records a
  decision the expression does not show and a constant cannot hold: a key
  built from arguments, a lookup together with its absent case, a type the
  expression would leave wide, or a module's private implementation. A
  function whose body is as clear as its name stays at the call site.
- Code that encodes a different rule stays at its own call site, however
  much it resembles a sibling helper. A builder that one call site uses is
  written at that call site.
- An abstraction that has grown a boolean or mode parameter, or a branch only
  one caller takes, is the wrong abstraction. Inline it back into each
  caller, delete what each caller does not use, then extract only what the
  callers truly share.
- A function whose parameter list keeps growing splits into simpler functions
  first. An options struct fits when most callers set several options.

**Smell baseline override.** These rules replace the generic Duplicated Code
smell: flag duplication only per the rules above.

## Go files and interfaces

**Hard.**

- The consumer declares dependency interfaces. Implementations return concrete
  types.
- A generated database row type has one mapper in the package that owns
  storage. Queries returning it call that mapper, so columns and UTC/null
  normalization change in one place.

**Judgement.** Files follow concepts or capabilities. New code joins the
concept it serves; a file edited for unrelated capabilities, or one
capability scattered across files, wants re-cutting along concepts.

## Construction

The leading word is **assembled**: a value its constructor returned has every
dependency it will ever call.

**Hard.**

- A dependency a method calls is a constructor argument, and the constructor
  rejects it when it is missing. A dependency used by only one process role
  is assembled by that role, so other roles never build it or hold its
  credentials. Request paths do not check for `nil`
  dependencies or answer "unavailable" for an unassembled one.
- A capability is a method on the interface the constructor requires. Code
  does not type-assert a dependency at runtime to discover an optional
  method: a fake that lacks the method skips the call and still compiles.
- A test seam stays out of the production API. An unexported constructor
  exported to tests through `export_test.go` serves the test; a public
  constructor widened to nilable interfaces leaks the seam into the contract.

**Judgement.** A `With*` method or a nilable field that switches a capability
on after construction is a runtime mode. Prefer passing the configuration to
the constructor, where an empty value means off, and decide once.

## Callers

The leading word is **caller**: every surface a change adds has a caller in
that change.

**Hard.**

- An exported symbol, interface method, option, config field, error code, or
  route with no caller outside its own test is deleted. It returns with its
  first caller.
- A branch that the code's own invariants make unreachable is deleted with
  the test that forced it. A guard repeated past a boundary that already
  guarantees the value is the same case; see Parsing at boundaries.

**Judgement.** A list, table, or registry with one entry is a singleton
dressed as a catalog. Write the single case directly and introduce the
catalog with the second entry.

**Judgement.** A mechanism outside the requested change waits for the
change that needs it, even when the code calls it.

**Smell baseline override.** These rules decide Speculative Generality.

## Failures

The leading word is **loud**: a miss, a parse failure, or missing
configuration reaches someone as an error.

**Hard.**

- A lookup that finds nothing fails or returns an explicit not-found. It does
  not fall back to the first item, a default row, or a zero value.
- A parse or validation failure is reported, not converted to "unset". A
  corrupt config file is a different outcome from a missing one.
- An unknown enum or mode value is an error at the point that reads it. The
  zero value of an `iota` enum or a `default:` branch does not stand in for a
  real member.
- A failure the caller can act on keeps its own reason. An infrastructure or
  configuration error is not reported as a user outcome (not found,
  permission denied, invalid input), and different failures do not share one
  code.

**Judgement.** A `default:` branch or a zero-value return that supplies a
value is a place to ask which invariant it hides. When the answer is "a value
that should always be present", remove the fallback and let the miss surface.

## Parsing at boundaries

The leading word is **parse**: a boundary turns loose input into a domain
type once, and code past the boundary trusts the type.

**Hard.**

- HTTP handlers and other edges parse wire input. A stored string is parsed
  where it is read. Past that point code passes the domain type, and the
  legal values live in that one parse function.
- A domain concept with a closed value set or an invariant gets a named type,
  its constants, and one parse function. A status does not travel as a free
  `string` that a later layer casts to the named type; the cast accepts any
  value.
- The value a boundary validates is the value it stores. When a field is
  trimmed or normalized for the check, the normalized value goes to the
  store.
- A generated type that does not fit is fixed in its generator: a schema or
  generator override, rather than a helper that converts between a generated
  pointer and a value or copies a pointer it could pass on. Generated files
  are committed and regenerated from their sources, never edited by hand.
  Regenerate after merging base changes even when generated output merges
  cleanly.

**Judgement.** A check repeated past the boundary, on a value the type
already guarantees, means the parse is missing or leaks.

**Smell baseline override.** These rules decide Primitive Obsession: flag it
only for concepts with a closed value set or an invariant.

## Reads and writes

The leading word is **scope-bound**: every lookup carries the scope its
caller is allowed to see.

**Hard.**

- A lookup that is allowed to see only part of the data passes that scope
  into the query. A lookup by a bare identifier returns a row the caller may
  not own.
- Uniqueness is decided by a unique constraint. The insert is the check, so
  concurrent writers cannot both pass it. The empty result of a conflict
  insert becomes the already-exists outcome when the caller must learn about
  the repeat. Where the process rule is to skip it, zero rows is not an error
  and no error value stands for it.
- Many rows written in one transaction take one statement per chunk, rather
  than one statement per row. With PostgreSQL, columns can travel as arrays
  and `unnest` turns them back into rows. A row-at-a-time loop holds locks
  while paying a round trip per row.
- A write a client may retry is idempotent, keyed by a natural or
  client-supplied key. A repeat of the same request returns the existing
  result. A different request on the same key is a conflict.

## Concurrency

A check **holds until commit**: it either is the statement that writes, or
locks what it read.

**Hard.**

- The guard on the row a statement writes goes in that statement:
  `UPDATE … WHERE id = $1 AND scope_id = $2 AND status IN (…) RETURNING …`.
  Zero rows is the miss, and the caller classifies it afterwards. Lock that
  row `FOR UPDATE` first only when the transaction does other work with it
  before the write.
- A check inside a transaction on another row that another writer can
  invalidate locks that row until commit: `FOR SHARE` to read it,
  `FOR UPDATE` to change it, and the parent row when the row may not exist
  yet. A plain `SELECT` lets the row change after the check passes.
- Writers that lock the same rows lock them in one order, stated by the
  deciding ADR or, without one, at the lock.

## Errors

The leading word is **handle once**: each error is returned, or logged, or
recovered from. Exactly one.

**Hard.**

- Code below the process edge returns errors. Logging happens at a boundary
  (see Logging).
- A wrap adds what the caller lacks: `fmt.Errorf("<verb> <noun>: %w", err)`,
  starting lowercase. The verb names the operation, so the message reads as
  a path of operations.
- Code branches on `errors.Is` and `errors.As` against sentinels and error
  types. `Error()` text is for humans.
- Names: exported sentinels `ErrXxx`, unexported `errXxx`, error types
  `XxxError`.
- The package that understands a failure translates it there. Callers above
  that package see the translated sentinel or wrapped error.
- A layer maps only the sentinels it recognizes. Any other error is wrapped
  and returned, so it reaches the HTTP edge as an internal error. A storage
  failure turned into a validation error, a permission error, or `false`
  hides an outage behind a user outcome.
- `panic` is reserved for programmer misuse caught at construction. Runtime
  and input failures return errors.
- `os.Exit` is called only in `cmd/*/main.go`.

**Judgement.** Use `%w` when a caller up the stack inspects the cause. Use
`%v` at a boundary where the cause's type should stop.

## Outbound calls

**Hard.**

- Every outbound call is bounded in time: the client sets a timeout, or the
  call runs under a `ctx` deadline. The call passes the caller's `ctx`.
- A client makes one attempt. Retry policy belongs to the caller, the only
  one that knows whether the operation is idempotent.
- A retry loop retries an idempotent operation, on an error that reports it
  can be retried, with capped exponential backoff and jitter.
- An outbound call runs outside a database transaction. A transaction holds
  row locks and a pooled connection, and rolling it back cannot undo a remote
  side effect. The order is: outbound work that can be compensated, then a
  short transaction that records it, then compensation when the transaction
  fails.
- The row that locates a remote object outlives the object. A delete or a
  state change that depends on the object checks the object first, and
  removes or advances the row only after the outbound step succeeded, or
  persists the intent so a retry can finish it.

## Logging

The leading word is **boundary**: the HTTP edge, job runners, and `cmd/` log.
Code inside the service returns errors and leaves logging to that edge.

**Hard.**

- A component that logs receives its logger from its constructor.
- Request- and job-scoped log lines carry context correlation/trace fields,
  so they join the operation's trace.
- The message is a fixed phrase. Varying data goes into structured fields
  with `snake_case` keys.
- An error field carries the error value.
- Fields hold identifiers. Passwords, tokens, session values, keys, and
  connection strings stay out of every field and message.
- Metric attributes come from closed sets: the method, the route template,
  the status code. Identifiers, raw paths, and user input go to traces and
  logs.

**Judgement.** Levels:

| Level | Meaning |
| --- | --- |
| Error | A person needs to act. |
| Warn | The process degraded and handled it itself. |
| Info | Lifecycle and request or job completion. |
| Debug | Diagnostic detail, off in deployed environments. |

## Time, context, and goroutines

**Hard.**

- A decision on the current time (expiry, freshness, revocation) reads an
  injected clock, so a test can set the time. Recorded timestamps come from
  the store.
- `context.Context` is the first parameter of anything that does I/O. The
  function uses the context it was given.
- A goroutine has an owner that stops it and waits for it.
- `init` stays free of I/O and global state.

## HTTP

Gin is the HTTP router.

**Hard.**

- Handlers parse the request, call into the service with typed values, and
  write the status. The service does not import Gin.
- `GET /healthz` is liveness and responds `204` when the process can serve.

**Judgement.** A metric or log that records a request uses the route
template, the pattern registered on the router, rather than the raw path.

## Names and comments

**Hard.**

- When the project has a glossary, identifiers, file names, error messages,
  and log messages use its terms. A term on a glossary _Avoid_ line is a
  violation.
- An exported identifier reads well after its package or module name.
- An ADR is cited by its filename or a Markdown link to that file, in
  comments and documents alike. The filename names the decision and resolves
  to one file.

**Judgement.**

- A comment states what the code cannot show: a constraint, a gotcha, the
  reason for an odd choice, or the ADR filename that decided it.
- Ticket and review identifiers belong in the commit and pull request, so a
  comment stays true after the review closes.
