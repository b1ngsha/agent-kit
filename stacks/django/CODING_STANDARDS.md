# Coding Standards

How this Django service is written where no linter decides. Authors apply
every rule while writing; a review applies every rule to the diff. A rule is
Hard unless under a Judgement label:

- **Hard**: a breach is a violation. Cite the file and section that state the rule.
- **Judgement**: report it as "possible …" with the reason, and let the author
  decide.

A **Judgement** label covers the rest of its section. A **Smell baseline
override** names the review smell the section replaces; it adds no rule.

A review judges the lines a diff adds or changes. Code the diff does not touch
is legacy, not a violation; it comes into line when a change touches it, or in
a refactor commit of its own.

## Owned elsewhere

These documents own their topic. Apply them as written.

| Topic | Owner |
| --- | --- |
| Django views, serializers, services, models, tasks, and clients | `docs/standards/code.md` |
| Tests | `docs/standards/testing.md` |
| Layer import directions, when configured | `pyproject.toml` import-linter contracts |
| Domain terms, when present | `GLOSSARY.md` |

Formatting (`ruff format`) and every rule enabled in `pyproject.toml` (ruff,
the type checker, import-linter) belong to the tools. Review accepts their
output as final. A rule that becomes mechanically checkable moves into the
tool config and leaves its document.

Where every source is silent, match the surrounding code. A change made only
to meet a standard keeps behavior identical and lands in its own commit,
apart from feature or fix work.

## Placement and extraction

The leading word is **colocate**: code sits beside its only caller until a
second owner needs it. Each layer a reader traces pays for itself.

**Hard.**

- A helper starts private (`_`-prefixed), in the module of its first caller.
  It moves outward one step at a time (module, then package, then a shared
  package) when a caller in the next scope needs it. A symbol moves together
  with its tests.
- A module or package is named for what it provides (`locking.py`,
  `policy_server_urls.py`). New code adds no `utils`, `helpers`, `common`,
  `misc`, `types`, or `constants` module; it joins or starts the concept
  module its contents share.
- One business rule (a validation, a state transition, a limit) has one
  source. That source appears when a second caller needs the decision.
- A repeated value (a literal, a lookup table, a key list) is one fact. The
  second file that needs the same value names it: naming adds no parameter
  and no branch, and two copies can drift.
- A helper appears when a second caller needs the same decision. Until then
  the expression stays at the call site. A name that only restates the
  expression does not earn the helper.
- When a reusable helper already exists (the project's `AppError` bases, a
  model's `TextChoices`, a queryset method), new code calls it. A
  hand-written second version of the same rule breaks the one-source rule
  above, even when it is shorter.

**Judgement.**

- Keep or extract a function that does at least one of these:
  - fixes a decision two or more callers share, such as a fallback message,
    a default, or a key shape;
  - names a domain concept the call site would otherwise explain in a
    comment;
  - forms the seam to an outside system (HTTP, object storage, a message
    broker), so the rest of the code works in domain types.
- Look-alike code that encodes different rules stays duplicated until the
  **third occurrence** that changes for the same reason (the Rule of Three).
  Two copies do not yet show which part varies.
- An abstraction that has grown a boolean or mode parameter, or a branch only
  one caller takes, is the wrong abstraction. Inline it back into each
  caller, delete what each caller does not use, then extract only what the
  callers truly share.
- A function whose parameter list keeps growing splits into simpler
  functions first. Keyword-only arguments fit when most callers set several
  options.
- A **pass-through** function, class, module, or test helper forwards to
  another without adding a decision. It fails the deletion test and is
  inlined.

**Smell baseline override.** These rules replace the generic Duplicated Code
smell: flag duplication only per the rules above. A view that validates, calls
one service, and serializes is the designed shape, not a Middle Man.

## Callers

The leading word is **caller**: every surface a change adds has a caller in
that change.

**Hard.**

- A public function, service function, serializer field, setting, or URL
  route with no caller outside its own test is deleted. It returns with its
  first caller.
- A branch that the code's own invariants make unreachable is deleted with
  the test that forced it (a status the writer never writes, a mode no caller
  selects). A guard repeated past a boundary that already guarantees the
  value is the same case; see Parsing at boundaries.

**Judgement.** A list, table, or registry with one entry, or a choices class
with one member nobody plans to extend in this slice, is a singleton dressed
as a catalog. Write the single case directly and introduce the catalog with
the second entry.

**Smell baseline override.** These rules decide Speculative Generality.

## Failures

The leading word is **loud**: a miss, a parse failure, or missing
configuration reaches someone as an error, in service, script, and test code
alike.

**Hard.**

- A lookup that finds nothing fails or returns an explicit not-found. It does
  not fall back to the first item, a default row, or an empty object
  (`.first()` where exactly one row must exist).
- A parse or validation failure is reported, not converted to "unset". A
  corrupt payload is a different outcome from a missing one, and
  `except ValueError: return None` erases the difference.
- An unknown enum or mode value is an error at the point that reads it. An
  `else` or a `.get(key, default)` does not stand in for a real member.
- A failure that the caller can act on keeps its own reason. An
  infrastructure or configuration error is not reported as a user outcome
  (invalid input, permission denied, not found), and different failures do
  not share one code.
- An `except` either handles the error (recovers, retries, maps it to a typed
  outcome) or re-raises it. Logging and continuing is handling only at a
  boundary that owns the log (see `docs/standards/code.md` Logging).

**Judgement.** An `or`, `except`, or `.get(key, default)` that supplies a
value is a place to ask which invariant it hides. When the answer is "a value
that should always be present", remove the fallback and let the miss surface.

## Parsing at boundaries

The leading word is **parse**: a boundary turns loose input into a trusted
type once, and code past the boundary trusts the type.

The boundaries are:

- Wire input: a DRF input serializer.
- Stored values: model fields, with closed sets as `TextChoices` /
  `IntegerChoices`.
- Outbound payloads: the typed schemas (Pydantic models or dataclasses) the
  client parses responses into.

**Hard.**

- Past the boundary, code passes the parsed type. The legal values live in
  the one serializer, schema, or choices class; a second list of the same
  values is a violation of Placement and extraction.
- A domain concept with a closed value set gets a named type (`TextChoices`,
  `IntegerChoices`, or an `Enum`). It does not travel as a free `str` that a
  later layer compares against literals.
- The value a boundary validates is the value it stores or uses. When a
  field is trimmed or normalized for the check, the normalized value moves
  on.

**Judgement.** A check repeated past the boundary, on a value the type
already guarantees, means the parse is missing or leaks.

**Smell baseline override.** These rules decide Primitive Obsession: flag it
only for concepts with a closed value set or an invariant. Database IDs and
UUIDs travel as plain `int` / `str`.

## Names and comments

**Hard.**

- When the project has a glossary, identifiers, file names, API fields, error
  messages, and log messages use its terms. A term on a glossary _Avoid_ line
  is a violation.
- Names follow PEP 8: `snake_case` modules, packages, functions, and
  variables; `PascalCase` classes; `UPPER_SNAKE` constants. A Python file name
  has no hyphen, scripts included, so it can be imported and tested.
- An ADR is cited by its filename or by a Markdown link to that file, in
  comments and documents alike.

**Judgement.**

- A comment states what the code cannot show: a constraint, a gotcha, the
  reason for an odd choice, or the ADR that decided it. A comment that
  restates the next line is noise.
- Ticket, PR, and review identifiers belong in the commit and the PR, so a
  comment stays true after the review closes.
- A docstring states the contract (what the caller gets, what it raises,
  what it must not do), such as "start requests must never auto-retry", not
  a summary of the body.

## Records

The leading word is **same change**: a change that alters a behavior also
edits every accepted record that states it.

**Hard.**

- Records are `AGENTS.md`, architecture documents, ADRs, the glossary,
  `README.md` command contracts, these standards, and the OpenAPI schema
  drf-spectacular generates from `extend_schema`, where the project has them.
  A diff that changes a command, a dependency direction, a route's
  permission, or an error code edits the record in the same PR.
- A superseded sentence is rewritten or deleted. A "superseded by" banner
  above a body that still states the old rule leaves two rules in force.
- A record describes the tree as it is. A file layout or route table that
  does not exist on disk is a second source of truth; change the code first,
  then the record.

**Judgement.** A new document that restates rules another record already owns
wants deleting in favor of a pointer to the owner.

## Dependencies

**Hard.**

- A pull request that adds a runtime dependency explains why the project
  cannot do without it and how it fares on the
  [OpenSSF Concise Guide](https://best.openssf.org/Concise-Guide-for-Evaluating-Open-Source-Software)
  questions: an existing component that already does the job, maintenance in
  the last 12 months, a published audit or security record, an OSI license,
  and the transitive dependencies it brings.
- The lockfile changes in the same commit as the manifest.

**Judgement.** Prefer a dependency with no transitive dependencies and an
independent audit over a larger one that does more.
