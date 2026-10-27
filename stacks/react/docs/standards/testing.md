# React Testing Standard

Read when: writing, reviewing, or moving a Web test. Rules are Hard unless
under a Judgement label, which covers the rest of its section.

A behaviour is asserted once, at the layer that owns it. A component test
renders what the user sees. A route test proves the URL mounted that
component. When another test already fails on the same bug, delete this copy.

## Stack and harnesses

- Runner: Vitest (`pnpm test`).
- Environment: jsdom for component tests. `src/test/setup.ts` calls Testing
  Library `cleanup()` in `afterEach`. Vitest globals stay off, so that call
  unmounts the tree. Leave `document.body` to cleanup; clearing its
  `innerHTML` first removes the container before React unmounts it.
- Render and queries: React Testing Library. Clicks and typing go through
  `@testing-library/user-event`.
- Route tests mount the real App and route tree through a shared harness,
  rather than a second registration stack. Internal module tests import the
  implementation directly rather than their own public barrel.
- When network mocks are needed, MSW serves the API with per-test default
  state and explicit seeds. Use generated factories when present and fail
  unhandled requests. Assert rendered outcomes, not mock-store contents.

## File placement

- A component with its own interaction or state gets a colocated
  `Name.test.tsx`.
- Tests that outgrow one file split by concern into
  `Name.<concern>.test.tsx`; the top-level `describe` matches that name.
- A route with a loader, redirect, or error gets a sibling `-route.test.tsx`.
  The `-` prefix keeps the route generator from treating the test as a route.
- Feature internals stay next to the file they verify. Registry completeness
  tests sit beside the registry.
- Shared support files are named by concept and colocated with their tests;
  support used across layers joins the common test harness.
- A URL that must 404 is tested by the route handling that 404. Asserting
  only that a path was never registered does not prove the behavior.

## Route coverage

Cover direct navigation and refresh for every registered route, and each
behavior [`routing.md`](./routing.md) states.

## Queries and network assertions

- New tests use `getByRole`, `getByLabelText`, or `getByText` and their
  `find*` / `query*` variants. They avoid `data-slot`, CSS selectors, and
  `container.textContent`.
- A test asserts what the user sees. Count or inspect requests only when
  the behavior has no visible sign, such as deduplicated reads or a one-way
  report. The test names that behavior and comments why the screen cannot
  show it.

**Judgement.** Prefer `findBy*` or `waitFor` over a one-shot query after an
async render.

## Test body layout

Apply [Vertical whitespace](./code.md#vertical-whitespace): one blank
line separates steps, each containing one action and its effects.

- Arrange comes first: seed data, render, and `userEvent.setup()` may share
  one paragraph or separate seed from render.
- An action, the wait for its effect, and assertions about that effect stay
  together. The next action starts a new paragraph.
- Setup preparing one action, such as an element reference or spy, belongs
  to that action's paragraph.
- Actions only reaching the state under test, without assertions on the
  way, are setup and may stay together.
- Separate `it` blocks with a blank line.

## Browser Mode

Move a component test to Vitest Browser Mode when jsdom cannot see the bug:
a layout failure or a browser API the test would otherwise stub. Give the
file a `.browser.test.tsx` suffix. Configure a Chromium Browser Mode project
with its own setup, excluded from the jsdom project, when adding the first
such test. Keep semantic queries so moving changes render and wait APIs.
End-to-end Playwright is a separate decision.

Browser layout tests load the application stylesheet, set the viewport, and
measure behavior (`scrollHeight`, `getBoundingClientRect`). Assert layout,
not Tailwind class names; a class string alone cannot prove what rendered.
