# Records

Read when: a change alters a behavior or contract (a command or output
contract, a state-file schema, a table, route security, an error code), or
adds an ADR or a document under `docs/`. Rules are Hard unless under a
Judgement label, which covers the rest of its section.

A change that alters a behavior edits, in the **same change**, every accepted
record that states it.

**Hard.**

- Records are architecture documents, ADRs, the glossary, README command and
  output contracts, operations guides, and the API contract, where the
  project has them. A diff that changes a command, a state-file schema, a
  table, a route's security, or an error code edits the record in the same
  change.
- A superseded sentence is rewritten or deleted; in an ADR it may instead
  stay in the past tense as the history of the decision. A "superseded by"
  banner above a body that still states the old rule leaves two rules in force.
- A record describes the tree as it is. A file layout, route table, or
  migration number that does not exist on disk is a second source of truth;
  change the code first, then the record.
- A decision whose code lands in a later change is an ADR marked
  `Status: Proposed.`, which the implementing change updates to
  `Status: Accepted.`. Until that code merges, current architecture, specs,
  and the ADRs it would replace keep describing the tree. The proposal's
  Consequences lists the records the implementing change rewrites. A planned
  module, table, or route stays out of current lists; its glossary term says
  it is proposed.

**Judgement.**

- A new document that restates rules another record already owns wants
  deleting in favor of a pointer to the owner.
- Notes about how a change was made (a delivery log, a consensus summary, a
  testing-architecture plan, a runbook that restates a command's flags)
  belong in the pull request description. A document lands under `docs/`
  only when a later reader needs it and the code cannot tell them.
