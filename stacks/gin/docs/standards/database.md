# Database Schema Standard

Read when: adding or changing a table, column, seeded row, or migration.
Rules are Hard unless under a Judgement label, which covers the rest of its
section. `CODING_STANDARDS.md` owns Reads and writes and Concurrency;
`testing.md` owns schema and migration verification.

A table stores a **fact** some code reads, and the schema keeps it true.

## Tables and columns

- A column pointing at another row has a foreign key. When the target must
  also have a kind or owner, a composite foreign key or trigger enforces it.
- Where names are case-insensitively unique, the database enforces that rule,
  such as an index on `LOWER(name)`.
- A table, column, or status waits for code that reads it, as
  `CODING_STANDARDS.md` Callers requires.

**Judgement.**

- A definition and its executions are separate facts and belong in separate
  tables.
- A forwarded request's outcome, an unread audit trail, or a status already
  determined by other columns is not stored.
- A seeded permission, role, or enum waits for code that checks it.
- A column every query coalesces to the same constant wants `NOT NULL` with
  that default. A NULL meaning absent stays nullable through domain and wire
  types, instead of being converted to a sentinel and back.

## Migrations

- `Down` restores what `Up` removed, including data, so the previous binary
  reads the rows it wrote. Moved values are copied back before dropping the
  new location.
- Branch migrations follow the latest base version in their original order.
  When the base adds a conflicting version, move all affected branch
  migrations above it without reordering create/alter dependencies. Update
  tests pinning those versions, including previous-version setup, and run
  migration and affected database tests.

**Judgement.** A new, unapplied migration is fixed in place instead of
appending a second migration that amends it.
