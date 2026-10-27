# API Contract Standard

Read when: adding or changing an OpenAPI operation, path, schema, field, or
response. Rules are Hard unless under a Judgement label, which covers the
rest of its section. Apply `CODING_STANDARDS.md` Callers to every operation,
field, and code.

## Paths

- Each path segment is a child of the previous one. Words without a
  parent-child relation form one segment. Scoped resources nest under the
  resource that owns their scope.
- The path addresses the resource; the body carries the command's own data.
- Path identifiers reuse shared parameter definitions with precise
  `<resource>_id` names.
- Reads use `GET` with query parameters, however few filters they take.

**Judgement.**

- A command other than create, replace, or delete is a verb sub-resource on
  the resource it changes.
- Steps a person runs separately are separate operations. A `mode` or
  `dry_run` flag switching between them hides a second contract.

## Bodies and fields

- Body schemas use `<Operation>Request` and `<Operation>Response`, after the
  operation ID.
- One concept has one wire name. Search for and reuse the existing name and
  ID schema instead of declaring a fresh primitive type.
- A request field is required only when the server rejects its absence. A
  response field is required only when the server sets it on every response.
- Closed sets use `enum`; unions use `oneOf` with a discriminator. A
  description alone does not enforce a contract.

**Judgement.**

- Outcomes of one decision share one body with a decision field.
- Human text has a maximum length; enums represent sets code branches on.
- Reuse a schema when the field set is the same. A different response field
  set gets its own schema rather than inheriting future fields accidentally.

## Responses

- Shared responses have one definition that operations reference. A shared
  response lists only error codes every referencing operation can send.
- A missing-resource response reuses that resource's existing definition.

**Judgement.** A missing path resource is `404`, an invalid body reference
is `400`, and a state preventing a command is `409`.

## Compatibility

- A change making existing calls fail or read differently is a break: a new
  required parameter or request field, removed or renamed field/enum/operation,
  narrower type or limit, or new security requirement.
- Regenerate SDKs and inspect exported symbols. A renamed or removed symbol
  is a break even when the schema change was additive. Resolve generated enum
  constant collisions with explicit generator names that preserve existing
  exports.
- Regenerate from sources after merging base changes even when generated
  output merges cleanly. Generated files are committed, never hand-edited.
