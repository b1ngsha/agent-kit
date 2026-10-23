# React Code Standard

Read when: writing or reviewing non-test React source. Generated code is
regenerated from its sources, never edited by hand. Rules are Hard unless
under a Judgement label, which covers the rest of its section.

## Placement and file names

Apply `CODING_STANDARDS.md` Placement and extraction. From a symbol's name,
a reader predicts its file; from a file's name, a reader predicts its exports.

- A module whose primary export is a React component is PascalCase and
  matches the component: `SceneSwitcher.tsx`. Every other module is
  kebab-case, including hooks and `.tsx` harnesses: `use-editor.ts`,
  `render-app-route.tsx`. Route files follow TanStack Router file syntax.
- Directories are kebab-case, except names a framework or test runner
  requires (`__tests__/`). A general collection is plural (`components/`,
  `hooks/`); a group around one concept is named after it (`pagination/`);
  one component with its private implementation takes the component's name
  (`VideoPlayer` → `video-player/`).
- A component or hook module has one primary export and is named after it.
  Private sub-components and helpers serving only that export share its file.
- Every other module is a **concept file**, named after the concept its
  exports share. The next symbol of the same concept fits without renaming
  it: `format.ts` can hold `formatByteSize` and `formatDuration`.
- An error class raised and caught in one file stays private there. When a
  second file needs it, it moves to the concept file that owns the condition.
  A module whose errors are raised from several files gathers them in
  `errors.ts`; it exports only errors caught outside that module.
- A file or directory name says what its contents are about. `utils`,
  `helpers`, `common`, and `misc` say only that the contents are code. A
  generator-required utility file keeps only what that generator requires.
- Split a file when a second concept appears, not when a second symbol does.

## Identifier and component API names

- Controlled props pair a value with its change callback: `value/onChange`
  for a generic value, or a specific name such as `page/onPageChange`.
- Custom booleans use `is` for state, `has` for presence, `can` for capability,
  and `should` for policy. Native attributes and props preserving a library's
  contract keep their names, such as `disabled`, `checked`, and `open`.
- Event callback props use `onX`; handlers inside the component use `handleX`,
  as in `onConfirm={handleConfirm}`. Business operations use action names
  such as `confirmImport`. Direct forwarding uses the existing function.
- A new API reuses the project's name for that concept, such as
  `open/onOpenChange` for dialog visibility.

## Layout inside a file

Sections appear in this order, one blank line apart:

1. Imports.
2. Module augmentation (`declare module`).
3. File-wide types and constants used by two or more declarations below.
4. Declarations.

A value, type, or helper serving exactly one declaration is **adjacent** to
it. A value sits directly above its user; a function helper sits directly
above or below. A single-use constant stays next to its user instead of
joining section 3.

A value stays at module scope when building it per call would repeat work or
change its identity: a schema, regular expression, lookup table, or object
passed as a React prop. Any other single-use value is inline at its use.
Exported and private declarations are otherwise free to interleave.
Untouched declarations keep their existing order.

## Vertical whitespace

- One blank line separates top-level declarations, including a type alias
  derived from the declaration above it. Consecutive imports, single-line
  re-exports, and one-line declarations of the same kind may stay grouped.
- Inside a function, a blank line separates steps: guard, compute, return.
  Each paragraph is one piece of logic: an action together with what it
  causes, or the lines preparing one value. Components, hooks, handlers,
  and tests follow this rule; tests add
  [Test body layout](./testing.md#test-body-layout).
- oxfmt removes leading, trailing, and repeated blank lines but never adds
  one, so review checks this section.

## Types, strings, and identifiers

- A closed set of strings is a literal union (`type Direction = "left" |
  "right"`). When code also iterates members or needs a named constant,
  declare an `as const` object and derive the union instead of using `enum`.
- A field required or permitted only in certain states is expressed with a
  discriminated union, rather than related optional fields in one object.
  Independent fields use an ordinary object type.
- A magic string repeated across files becomes a named constant or joins a
  union at the repeated-value threshold in `CODING_STANDARDS.md`.
- Compare string literals against values already typed as literal unions.
  Narrow plain strings from URLs, storage, or APIs once at the boundary,
  with a schema or type guard. Open browser sets such as `event.key` stay
  strings; the closed subset the app branches on gets a literal union.
- When behavior varies per member, represent the variation as a table or an
  exhaustive `switch`, so adding a member fails compilation wherever it
  needs handling. A ternary on the member being iterated belongs in the
  table's pairing.
- A limit declared in an API schema has one schema-derived binding per
  field. Use generated constraint constants when the generator exposes them;
  otherwise keep one binding tied to that schema constraint. Callers read
  the binding instead of repeating numbers. A limit described only in prose
  stays literal until the schema declares it.
- An identifier is opaque. Keep data in typed fields rather than building
  strings such as `segment-${n}` and later parsing them back. Produce strings
  only at the edge.
- When a caller or test must distinguish outcomes, return a typed reason
  (a literal or discriminated union); presentation maps reasons to copy.
  Copy is exported only for display. A test asserts the reason or screen.
- A view-model type crossing a public module boundary is declared by name.
  `ReturnType<typeof …>` is for library-shaped values such as query options
  and hook results. Components, hooks, and query options keep inferred returns.

## State and effects

An **external system** is something outside React that a component
synchronizes with, as React's
[You Might Not Need an Effect](https://react.dev/learn/you-might-not-need-an-effect)
uses the term.

- When a parent needs a child's state, the state lives in the parent, or both
  update in the same event handler. An Effect reporting state upward is the
  [anti-pattern](https://react.dev/learn/you-might-not-need-an-effect#notifying-parent-components-about-state-changes).
- A prop read only on mount to seed state is named `initial…` or `default…`.
  The child reads that one prop; the parent passes no value derived from it
  alongside, such as `revision` beside `initial.revision`.
- Dialog draft and form state live in content that unmounts on close, so the
  next open starts empty. Resetting it by comparing `open` during render
  defeats that ownership.
- A one-shot command dialog may close while its request is in flight. It
  stays open when closing would lose input needed to retry, a secret shown
  once, or an operation's progress and cancel control.
- After a command succeeds, a failed list refresh shows the page's
  refresh-error state; the command still reads as a success.

**Judgement.**

- `useEffect` synchronizes with an external system: a media element, a window
  listener, or an observer.
- Values computable from props, state, or query data are computed during
  render. Server data stays in the TanStack Query cache.
- Form fields read only on submission can manage their own values. Use
  controlled state when a field drives rendering, dependencies between
  fields, or programmatic updates. Choose per field.
- State pointing at server data holds an ID, not a copy of the row. Derive
  the row from the latest query result each render, so refetch updates open
  dialogs and a vanished row closes them. A selection changing a server
  query is URL search state.
- Work caused by a user event runs in that event's handler.

## Server writes

A write the user starts is **one mutation**: one TanStack Query mutation,
whose progress the screen reads from the mutation cache.

- Several requests forming one write (begin, signed PUT, complete) share one
  `mutationFn`, including compensation if a later step fails. The component
  calls that mutation, so it stays pending throughout and unmounting cannot
  skip cleanup. Chaining mutations or calling the client between them
  breaks both guarantees.
- In-flight state comes from the mutation cache. Mutations locking the same
  controls share a `mutationKey`; the screen reads them with `useIsMutating`,
  rather than busy flags or `onBusyChange` callbacks between components.
- Read user-selected files in chunks (`blob.slice`) or as streams. Reading
  the whole file with `blob.arrayBuffer()` holds it in memory. For large-file
  checksums use incremental hashing; Web Crypto `digest` has no stream input.

**Judgement.** Time between writes the user sees as one action, such as a
refetch before an editor closes, is outside the mutation cache. Hold it as
named state in the component owning the action, rather than a second busy
channel.

## Accessible names

Controls sharing a role on one screen have **unique** accessible names,
unless they do the same thing.

- A control repeated per item names its item, so a screen reader hears the
  difference and a test finds it with `getByRole` without an index.
- An icon-only control has an `aria-label`; its icon is `aria-hidden`.

## Styling

A visual value is a design **token**: it has one home in the theme or a
primitive's variants, and consumers select it.

- Library-owned primitives keep their role. Product chrome goes on consumers
  through their `className` hook.
- Product colors and shadows are CSS variables in the theme, so dark mode
  and a second consumer follow them. A color literal in a component's class
  is a second source.
- Consumers select existing variants or sizes. A missing height or state
  becomes a primitive variant. External overrides of the primitive's border
  or state background add a layer that breaks on its next update.
- Classes serving removed behavior leave with it.
