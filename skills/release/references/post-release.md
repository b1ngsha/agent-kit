# Post-Release Synchronization

Consult when docs, READMEs, or external wikis reference a version pin (e.g., `@vX.Y.Z`, image tag, or SDK install snippet).

## Ordering Rule

Always create and push the tag **before** updating version-pinned docs:

- **External docs (Feishu Wiki, Notion, internal portal)**: safe to update immediately after the tag is pushed and confirmed on `origin`.
- **In-repo docs (`README.md`, `docs/*.md`)**: leave out of the tagged commit unless the user explicitly asks to include a pre-tag doc commit, so the tag stays anchored on the already-tested `verified SHA`. Propose a follow-up doc commit/PR after release if desired.

## Execution & Verification

1. Locate every version reference before editing (search for the previous tag or unpinned repo URL).
2. Update only the approved targets using the appropriate tool (e.g., `lark-doc` for Feishu Wiki).
3. Read back the modified section/revision after writing to satisfy `remote-verified` in Step 4.
