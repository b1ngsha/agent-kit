# Repo Maintenance

Read the section whose trigger matches the change. Rules are Hard unless
under a Judgement label, which covers the rest of its section.

## Editing a CI job or script

Read when: adding or editing a CI job or a script it runs.

A step only one CI job calls lives in that job's script. A separate program
earns its place when people also run it.

## Adding a runtime dependency

Read when: a change adds a runtime dependency or changes its lockfile.

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
