# Coding Standards

How this app is written where no linter decides. Authors apply every rule
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
| React source | `docs/standards/code.md` |
| React state, effects, and mutations | `docs/standards/state.md` |
| Routes and URL state | `docs/standards/routing.md` |
| Tests | `docs/standards/testing.md` |
| Records: behavior or contract changes, new ADRs and documents | `docs/standards/records.md` |
| CI jobs, scripts, and runtime dependencies | `docs/standards/repo-maintenance.md` |

Formatting (oxfmt) and every rule enabled in `.oxlintrc.json` belong to the
tools. `pnpm format`, `pnpm lint`, and `pnpm test` run them.
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
  one step at a time (file, then a shared module) when a caller in
  the next scope needs it. A symbol moves together with its tests.
- A second file that needs a private helper's decision imports the moved
  helper. Before adding a helper, search the tree for one that already
  decides the same thing and call it. A copy under another name, a shorter
  one, or one written inline at the call site is still a copy.
- A module is named for what it provides. Shared code joins a module
  with that kind of name.
- One business rule (a validation, a state transition, a limit) has one
  source: the helper born at the third production call site. A test drives
  one of those sites.
- A repeated value (a literal, a lookup table, a key list) is one fact. The
  second file that needs it names it: naming adds no parameter and no branch,
  and two copies drift.
- A value that several callers share (a fallback message, a default, a limit,
  an error code) is held once: as the default of the parameter it fills when
  most calls want it, otherwise as a named constant each caller passes.
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
  first. An options object fits when most callers set several options.

**Smell baseline override.** These rules replace the generic Duplicated Code
smell: flag duplication only per the rules above.

## Callers

The leading word is **caller**: every surface a change adds has a caller in
that change.

**Hard.**

- An exported symbol, interface member, prop, option, config field, error
  code, or route with no caller outside its own test is deleted. It returns with its first caller.
- A branch that the code's own invariants make unreachable is deleted with
  the test that forced it. A guard repeated past a boundary that already
  guarantees the value is the same case.

**Judgement.** A list, table, or registry with one entry, or a union with one
member nobody plans to extend in this change, is a singleton dressed as a catalog. Write the single case directly
and introduce the catalog with the second entry.

**Judgement.** A mechanism outside the requested change waits for the
change that needs it, even when the code calls it.

**Smell baseline override.** These rules decide Speculative Generality.

## Failures

The leading word is **loud**: a miss, a parse failure, or missing
configuration reaches someone as an error. App code and mock code alike.

**Hard.**

- A lookup that finds nothing fails or returns an explicit not-found. It does
  not fall back to the first item, a default row, or an empty object
  (`?? items[0]`, `{ name: "Untitled" }`).
- A parse or validation failure is reported, not converted to "unset".
  `.catch(undefined)` or `catch { return null }` erases the difference
  between missing and corrupt.
- An unknown enum or mode value is an error at the point that reads it. A
  `default:` branch does not stand in for a real member.
- A failure the user can act on keeps its own reason. A network or
  configuration error is not shown as a user outcome (cancelled, permission
  denied, invalid input), and different actionable failures carry different
  codes.

**Judgement.** A `??`, `||`, `catch`, or `default` that supplies a value is a
place to ask which invariant it hides. When the answer is "a value that
should always be present", remove the fallback and let the miss surface.

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
