# React Routing Standard

Read when: adding or changing a route, search parameters, navigation, or
route pending/error behavior. Rules are Hard unless under a Judgement label,
which covers the rest of its section.

## Technology and route files

TanStack Router owns the URL. TanStack Query owns remote-data freshness and
caching.

- File routes live under `src/routes/`. The Vite plugin is
  `@tanstack/router-plugin/vite`, registered before React, with
  `autoCodeSplitting: true`. Generated route types stay enabled.
- `src/routeTree.gen.ts` is generated and committed. Lint and format ignore
  it. Regenerate after changing its sources and after merging base changes,
  even when the generated diff merges cleanly; hand edits are discarded.
- A route file exports only `Route`. Route-only helpers live in sibling
  files or directories prefixed with `-`, so the generator skips them.
- A route is registered with its feature and applicable route tests from
  [Route coverage](./testing.md#route-coverage).
- A non-root deployment changes the Vite base, Router base path, and edge
  server location together.
- A Router major-version upgrade is its own migration, with its Vite plugin
  and any Devtools or lint plugins moved to compatible versions.

## URLs and search

- Path segments are lowercase English `kebab-case`; collections are plural
  nouns. Resource routes are nouns; UI-only creation routes may use `new`.
- Parameters name the thing (`sceneId`), using camelCase in TypeScript.
- Web URLs stay independent of the API version.
- Each resource has one canonical URL carrying a stable ID. Mutable display
  names stay out of canonical paths.
- State changing a server query and needing to survive refresh, sharing, or
  back/forward navigation lives in the URL: committed filters, sorting,
  discrete pagination, and time ranges. Transient input, dialog visibility,
  hover, expansion, and the count of materialized load-more pages stay local.
- Search objects are validated and normalized with a schema. Names align
  with the API; canonical URLs omit defaults and strip empty/unknown values.
- A return destination accepts only an app-relative path beginning with
  one `/`; absolute and scheme-relative URLs are rejected.
- URL normalization and debounced search commits replace the history entry.
- Cursor pagination clears its token when filters, sorting, time ranges, or
  page size change. Invalid or expired tokens return to the first page and
  tell the user what happened.
- Params, search, links, and navigation use route-specific APIs or explicit
  `from` values, keeping TypeScript types narrow. Register the Router type
  through declaration merging.

## Router and Query responsibilities

- `beforeLoad` handles redirects and route-context setup; `loaderDeps`
  derives stable dependencies from validated params and search.
- A loader awaits `ensureQueryData` or `ensureInfiniteQueryData` for data
  required to render. `prefetchQuery` swallows failure and cannot enforce
  that requirement.
- Loaders and `beforeLoad` stay free of mutations and business writes:
  preloading runs them too. Expensive routes may turn preloading off.
- Loader data stays lightweight and exists only when route behavior needs
  it. Await Query operations without copying remote rows into Router state.

**Judgement.** A mutation caused by a click runs in its handler, then
invalidates the query.

## Head and navigation labels

- The Root renders `HeadContent`. Titles come from native route `head`
  options, with no static `<title>` in `index.html` or component writes to
  `document.title`.
- One shared builder owns the title format. The deepest matching title
  wins; Router does not concatenate title segments. `head` treats
  `loaderData` as optional and always supplies a stable fallback.
- Labels show resolved domain names. While loading they use a stable
  fallback or skeleton; failed lookups show an explicit unavailable state.
- A static route title and breadcrumb reuse one display-name constant.
  Navigation order is explicit and destinations use typed Router values.

## Pending, error, and not-found behavior

- Route states render at the nearest applicable layout boundary. First-load
  pending uses the Router pending component instead of a second page spinner.
- Initial failure replaces route content. Retry resets the Query error
  boundary and invalidates the Router.
- A background-refresh failure keeps visible stale data with a non-blocking
  warning; permission failure hides data the caller may no longer access.
- API errors display a copyable correlation ID when available.
- A resource miss is classified in the loader before the page renders. Its
  not-found component works without that loader's data, and the closest
  valid layout stays visible.
