# Monorepo & Multi-Package Versioning

Consult when Step 1 detects multiple versioned packages (e.g., workspace backend + frontend + embedded SDK/library).

## Unified Tag vs. Package-Scoped Tag

Choose one tagging strategy and state the rationale in the `dry plan`:

- **Unified tag (`vX.Y.Z`)** — default when packages share a release cadence or a tightly coupled runtime contract (e.g., gateway + SDK headers, API + SPA). All manifests keep `manifest parity` at `X.Y.Z`, giving consumers a single version coordinate.
- **Package-scoped tag (`<pkg>-vX.Y.Z`)** — choose when one package ships independently on a much higher cadence or serves external consumers with a separate compatibility promise. Resolve the baseline tag with the same prefix (`git ls-remote --tags origin '<pkg>-v*'`).

## Manifest Parity Audit

Check every version declaration in the workspace before proposing the tag:

- Package manifests (`pyproject.toml`, `package.json`, `Cargo.toml`, `go.mod` / module path)
- Runtime version constants (`__version__`, `VERSION`, CLI `--version` strings)
- Lockfiles or workspace cross-references when a version bump changes them

If all relevant manifests already match the target version (common on an initial `v0.1.0` cut), tag the `verified SHA` directly without a redundant bump commit. If any manifest lags behind, include the exact file list in the pre-tag commit section of the `dry plan`.

## Git-Installed Subdirectory SDKs

When downstream projects install an embedded package via git URL, include the pinned install snippet in both Release Notes and the announcement:

- Python (`uv`): `uv add "<pkg> @ git+<repo-url>@<tag>#subdirectory=<path>"`
- Go / npm / other ecosystems: follow the repository's documented install syntax, substituting `<tag>`.
