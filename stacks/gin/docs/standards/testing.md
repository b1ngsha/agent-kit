# Go Testing Standard

Read when: writing or reviewing a Go test, or choosing which layer owns an
assertion. Rules are Hard unless under a Judgement label, which covers the
rest of its section.

A behaviour is asserted once, at the layer that owns it. Before adding a
test, name the owner. When another layer already catches it, delete this
copy. When nothing catches it, move the assertion to the owner.

**Judgement.** Before keeping a test, ask: if this file disappeared, would
any bug become uncaught?

## Owners

| Layer | Owns |
| --- | --- |
| The package that decides the rule | Business rules, state transitions, validation |
| The package that talks to a database | SQL translation and constraint outcomes, against a real database |
| The HTTP handler | Routing, decoding, and status mapping, with the inner service fabricated |
| Schema and integration | Database-only constraints, locks, migration, rollback, and process assembly against a real migrated database |
| API contract and SDK, when present | Schema constraints, documented error-code completeness, and client encoding/decoding |

Put the assertion in the owner's file. A status code belongs beside the
handler that writes it. A unique-constraint outcome belongs beside the code
that maps that constraint.

## Database verification

- Service branch tests use in-memory dependencies. Database locks require a
  real migrated database and production assembly, with forced interleaving
  that holds one transaction open while another attempts the competing write.
  An in-memory transaction callback cannot prove a lock.
- A database-backed change is verified when its test body runs against the
  database. Compile-only checks do not verify it. A narrowed `go test -run`
  must not report `no tests to run`.
- Missing required database configuration fails database-backed tests;
  service and handler tests remain independent of it. Live external-service
  tests may opt into a separate integration build tag.
- Schema tests use SQL for invariants the database alone enforces, including
  defense-in-depth constraints. They do not replay service flows.
- A data migration test starts with the previous schema and stored row shape,
  migrates up and asserts the conversion, then migrates down and asserts
  what the previous version reads. Seed data alone does not test conversion.
- Cross-table given-state goes through the owning fixture, so a column change
  edits one insert.

## Names and packages

- Public service behavior and database translation tests use external
  `_test` packages. Private implementation packages may test white-box;
  `export_test.go` can expose a private assembly seam to external tests.
- `<production-file>_test.go` tests that file. Doubles are named for their
  interfaces, with one double per file; builders shared by test files live
  in `fixture_test.go`.
- Tests use `Test<Capability>_<Condition>`. Related inputs share a named
  `t.Run` table so a row can be selected independently and one failure leaves
  other rows running. Row names use letters and digits; `/` separates test
  selectors.

## Doubles

**Hard.**

- A double implements every interface method it claims. It does not embed
  the interface to satisfy a compile-time assertion: an unset embedded
  interface lets a missing method compile and panic on a `nil` call.
- A method the test did not stub fails the test (`t.Fatalf`, or an error the
  test cannot mistake for success) rather than returning a zero value that
  sends the code down a default path.
- A counter or a recorded call exists only when an assertion reads it. One
  fake per interface: a second test that needs a new behavior extends the
  existing fake rather than wrapping it in another type.
- A harness function that only forwards one call is pass-through; call the
  original. A test that needs the router builds it with the production
  constructor, not a second registration stack.

## Shape

**Hard.**

- A test arranges one situation, calls one capability, and checks the outcome
  that capability owns. A fallible helper takes `t` first and calls
  `t.Helper`; result assertions stay in the test. Seed a fake through the
  method that already writes it.
- A handler test calls the handler with an `httptest` request. It fabricates
  the service result. It does not open a database to prove a status code.
- A rule test calls the function that owns the rule. It does not boot Gin to
  prove a validation.
- A test name states the behaviour: `TestHealthz` reports liveness, not
  `TestHandler`.

**Judgement.** Two tests that fail on the same bug are one test too many.
Keep the one at the owning layer.
