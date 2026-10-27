# React State Standard

Read when: adding or changing React state, an effect, or a mutation. Rules
are Hard unless under a Judgement label, which covers the rest of its
section.

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
  query is URL search state ([URLs and search](./routing.md#urls-and-search)).
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
