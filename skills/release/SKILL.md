---
name: release
description: 交互式发版：盘点远端状态与版本文件、生成 Release Notes 与飞书发布公告、对过 CI 的提交打 tag 并发布 Release，最后远端回读验收。
disable-model-invocation: true
---

# Release

Cut a versioned release through four gated phases: inspect remote truth, present a `dry plan`, execute only approved actions, and close `remote-verified`.

**Language rule**: All user-facing interaction, questions, Release Notes, Release Announcements, and final reports are written in Chinese unless the user asks for another language.

## Shared Terms

- **`verified SHA`**: The exact commit SHA on the remote target branch whose CI checks have completed and passed.
- **`manifest parity`**: All version-bearing manifests in the repo agree with the target version (or every intentional exception is explicitly listed).
- **`dry plan`**: The complete, reviewable release proposal—target SHA, tag decision, action list, Release Notes, and Feishu announcement—presented before any mutation.
- **`remote-verified`**: Every claimed tag, release, or synced doc is confirmed by reading back remote state in this session.

## Step 1: Inspect (read-only)

Keep the working tree untouched throughout this step.

1. Sync remote refs and tags (`git fetch origin --tags --prune`).
2. Identify the target branch and its **`verified SHA`**. Default to the repository's default branch on `origin` (e.g. `origin/main` or `origin/master`); ask only if the user hints at another branch or multiple release branches are plausible. Check the CI run status for that SHA on the repository host.
3. Resolve the baseline tag from `origin` (`git ls-remote --tags origin`) so stale local tags never skew the diff range:
   - Baseline tag found → diff range is `<baseline>..origin/<branch>`. If the baseline tag already points at the `verified SHA`, stop and inform the user that there are no new commits to release.
   - No remote tags → treat as initial release and use full history on the target branch.
4. Scan version manifests across the repository (`pyproject.toml`, `package.json`, `Cargo.toml`, `__version__`, etc.) to assess **`manifest parity`**, and note existing release conventions (whether `CHANGELOG.md` is tracked, existing platform Releases, install docs referencing git tags).
5. **Branch pointer**: If the repository has multiple versioned packages or an embedded SDK/library, read [`references/monorepo-versioning.md`](references/monorepo-versioning.md) before proposing a tag scheme.

**Done when**: target branch, `verified SHA`, CI status, remote baseline tag (or first release), every manifest version, and repo conventions are established with zero worktree modifications.

## Step 2: Propose & Draft (`dry plan`)

1. Inspect the change set (`git log` and `git diff --stat`, plus key file diffs where subjects are vague) and derive the semantic version bump from actual user-facing impact:

   | Bump | Trigger |
   | --- | --- |
   | `major` (`x.0.0`) | Breaking API, wire-header, config, CLI, or schema changes; removed user-facing capabilities |
   | `minor` (`x.y.0`) | Backward-compatible new features, endpoints, packages, or capabilities |
   | `patch` (`x.y.z`) | Bug fixes, refactors, performance, tests, docs, or build/CI maintenance |
   | Initial release | Default to `v0.1.0` (first usable pre-1.0) or `v1.0.0` (committed stable contract); explain choice |

   Take the highest bump present. When borderline between `major` and `minor` (or `v0.1.0` vs `v1.0.0`), state the trade-off and recommend one.

2. Choose the tagging path:
   - **Direct tag on `verified SHA`**: When `manifest parity` already holds and no tracked `CHANGELOG.md` update is needed, tag the `verified SHA` directly. This works safely even when the local checkout is on another branch or has unrelated untracked files.
   - **Pre-tag release commit**: Needed only when manifest versions must be bumped or tracked `CHANGELOG.md` must be updated before tagging. If the current worktree has unrelated WIP, run the release commit from a clean detached/temporary worktree rather than disturbing user files.

3. Read [`references/artifacts.md`](references/artifacts.md) and draft **both** deliverables:
   - **Release Notes / Changelog** (technical, upgrade-oriented).
   - **Feishu-ready Release Announcement** (lively, humorous, playful, directly copy-pasteable into Feishu).

4. **Branch pointer**: If docs, READMEs, or external wikis (e.g. Feishu Wiki) pin a release tag or SDK install command, read [`references/post-release.md`](references/post-release.md) and list them as optional post-tag actions.

5. Present the complete **`dry plan`** in one message:
   - Target branch, `verified SHA`, and CI result
   - Version decision (`<baseline> -> <next>`) and rationale (including `manifest parity` status)
   - Numbered list of exact outward actions awaiting approval (pre-tag commit if any, annotated tag + push, platform Release, optional post-release doc sync)
   - Full **Release Notes** draft
   - Full **Feishu Release Announcement** draft

6. Wait for explicit user approval. If the user adjusts the version, wording, or action scope, update the affected pieces and re-confirm before executing.

**Done when**: the full `dry plan` and both drafts are presented, and the user has explicitly approved the exact set of actions to execute.

## Step 3: Execute (approved actions only)

Run only the actions approved in Step 2, in strict order:

1. **Pre-tag commit** *(only if approved)*: update version manifests and/or `CHANGELOG.md`, commit cleanly, push the target branch, and record the new commit as the `verified SHA`.
2. **Tag & push**: create an annotated tag directly on the `verified SHA` (`git tag -a <tag> <sha> -m "Release <tag>"`) and push it (`git push origin <tag>`).
3. **Platform Release** *(only if approved)*: publish the release using the host's native CLI (e.g. `gh release create <tag> --title "<tag>" --notes ...` on GitHub) with the approved Release Notes.
4. **Post-release sync** *(only approved items)*: follow [`references/post-release.md`](references/post-release.md) to update approved external/internal docs.

If any command fails, stop immediately, report the exact command, error output, and current local/remote state, and ask how to proceed. Preserve pushed history—recover forward rather than force-pushing or amending pushed commits.

**Done when**: every approved action has exited cleanly.

## Step 4: Verify & Report (`remote-verified`)

1. Read back remote truth for every executed action:
   - Confirm the tag on `origin` resolves to the intended `verified SHA`.
   - Confirm the published Release URL, target, and non-draft status (e.g. `gh release view <tag> --json ...`).
   - Confirm any updated external doc revision or snippet reflects the new tag.
2. Output a concise numbered ledger covering `已完成` / `未适用` / `待后续处理` with links and verified SHAs. If the Feishu announcement changed during approval, reprint the final copy-ready block at the end.

**Done when**: every completed item in the report is backed by a read-back observation from this session.
