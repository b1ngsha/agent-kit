---
name: find-simplifications
description: Find evidence-backed simplifications in code, APIs, configuration, tests, and prose; write or consolidate proposals, identify small inline cleanups, assess ideas from another branch, or retire superseded design records. Use when the user asks what can be simplified, removed, or deleted from a codebase.
---

# Finding Simplifications

Find changes that remove maintained obligations: APIs, representations, lifecycle states, configuration paths, dependencies, tests, or documentation. Prefer a few well-supported candidates over a count of deletions. Keep the user's scope and distinguish a survey from permission to implement its proposals.

## Establish scope and constraints

Read the repo's agent instructions (`AGENTS.md`, `CLAUDE.md`), contributor and architecture docs, defensive-pattern guidance, testing policy, and relevant active decision records before judging code. Designs marked intentional are protected by default: collapsing one must beat its recorded rationale and remain within the user's authorization. Unused members within a protected seam remain candidates when removing them preserves its purpose.

Requirements, checks, and records introduced by the code under review are design choices to assess, not independent evidence that its distinctions are necessary. Follow the repo's archive policy; frozen historical records are examples, not current authority, and their outbound links do not become a repair task.

For broad requests, derive independent survey domains from the repo: entry points and the core loop, API and protocol layers, persistence, integrations, composition, packages, tests, scripts, and prose. Delegate bounded domains when subagents are available and require consumer evidence and rejected alternatives; otherwise walk the same domains yourself. Inspect substantial production machinery as well as obvious unused symbols. A strong early candidate is a data point, not a finish line.

## Search for removable obligations

Use these questions to guide discovery. Read [simplification patterns](references/simplification-patterns.md) when a candidate needs calibration; the examples describe trade-offs, not a deletion inventory.

- **Does a declared feature have a complete effect path?** Trace producer, transformations, provider or endpoint support, and observable result. A field copied everywhere may have no setter, no reader, or only implementations that reject it. For CLI and configuration pass-throughs, follow authoritative reads and precedence to find forwarded values shadowed before use. Search constructors and discriminant emitters as well as callers.
- **Which distinctions change a consumer's action?** First ask whether the distinction, field, or adapter is needed at all. Trace source fields and discriminants through emitters and authorization or capability checks before adding another marker. Consider deleting a distinction separately from relocating its declaration, and state which inputs or capabilities each alternative admits. Preserve required authorization, residency, durability, and ownership behavior.
- **Could a smaller explicit behavior remove the subsystem?** Fixed intervals, caller-supplied settings, or reported activation failure may eliminate generalized scheduling, persisted defaults, or automatic rollback. Name the capability given up and the machinery deleted. A production caller makes this a behavior decision, not an automatic rejection; implementation must remain within the user's authorization.
- **Can a consumer read the authoritative value when needed?** Look for copied histories, promotion ledgers, mirrored flags, invalidation events followed by reads, and caches beside a shared projection stream. Derivation or reuse may delete subscriptions, retained data, stale-response handling, and recovery paths together. Establish the required time of observation first.
- **Is composition being mistaken for policy?** Optional service presence, a provider method, or a sibling tool can express availability without deciding deployment behavior. Explicit configuration or a caller-intent operation may remove registries and dependency checks. Preserve distinct operations when ownership or completion timing differs.
- **What owns the complete maintenance cost?** Trace duplicate application trees, demo launchers used by products, resolver-only packages, and installation helpers with their own upgrade lifecycle. For required behavior, compare existing producer/consumer extension points with changes to distant shared declarations. Include residual glue: moving an unnecessary concept or adding a consistency gate does not remove its cost.

A typo, one dead-code-tool result, or "this looks complex" without consumer evidence does not earn a proposal.

## Prove reachability and the trade-off

Start with `rg`, then read the matches. Search exact symbols, property reads and writes, discriminants, event and wire strings, config keys, package names, and both `.method(` and `method(` forms. Tests and declarations can show a contract without proving a shipped producer or consumer.

Classify the corpus before deciding:

- **Production:** shipped source, runtime configuration, deployment scripts, profiles and overlays, manifests and exports, loader resolution, generated runtime assets, and installed-package consumers.
- **Non-production:** tests, docs, comments, snapshots, and generated expected outputs.
- **Ambiguous:** examples, demos, fixtures, and scripts; read their entry points and actual use before classifying them.

Follow dynamic loading, reflection, dependency injection, and generated catalogs to their consumers. A catalog used through generic plugin invocation is a product API even with no fixed caller. Public third-party extension paths may be intentional despite zero repository call sites. An unused-code tool helps only to the extent it covers these loading and compilation paths; avoid maintaining a parallel exception inventory to make it agree.

For each candidate, record its current owner, effective producer/consumer path, what disappears, what remains, capability and compatibility effects, and the strongest reason to retain it. Distinguish:

- removal of unreachable or unread behavior;
- a narrower public or product behavior with an explicit loss;
- a protected obligation or insufficient evidence.

Reject candidates that break retained obligations, merely relocate complexity, force unrelated churn without reducing obligations, or offer no meaningful reduction. Read prior rejection reasons at the scope of the proposed change: a stale inventory or one rejected part of a mixed proposal does not settle every independent item. Refresh the evidence before re-proposing it. Small local improvements belong in actionable inline notes rather than standalone design records.

## Preserve ownership and failure semantics

For copies, freezes, validators, and callback captures, name the value's origin, next owner, and trust boundary. Typed same-process calls ordinarily borrow readonly values; parsers, config loaders, queues, external JSON, durable files, workers, processes, and wire decoders own or validate their inputs. Hostile getters, fabricated typed objects, or mutation after handoff do not establish a requirement by themselves. A frozen root does not prove its descendants immutable, and equal IDs do not prove object identity.

A runtime invariant, consistency checker, or health probe earns its place when it compares independently produced observations that can diverge. Mere presence checks, static metadata, fixed examples, or rereading the same mutation are candidates for removal when they protect no retained contract. Include check-only exports, build entries, dependencies, and tests in the proposal, and record why the check was dropped where the next maintainer will look.

For asynchronous machinery, map each promise, flag, cancellation path, disposer, and reservation to its owner and transition. Collapse mechanisms only when they express the same fact. Preserve synchronous publication and rollback, callback containment, first-terminal-outcome arbitration, worker/process ownership, and dispose-to-quiescence where required. Durable start/end markers may record real facts even when a renderer ignores them; dropping interrupted work is a capability loss.

## Replace infrastructure only for a net reduction

Follow the repo's dependency policy. Search existing dependencies and standard-library facilities at the supported version floor before adding a package. Identify the exact implementation and dedicated tests the replacement deletes, its maintenance, license, security, and transitive cost, and every residual behavior the glue must preserve.

Exercise the mismatches most likely to defeat the replacement: protocol truncation, cancellation and teardown, configured bounds, deterministic test clocks, platform packaging, and source versus built entry points. A library that needs the same infrastructure rebuilt around it is not a simplification. State accepted behavior changes in the proposal and relevant tests. Test the application-specific shim rather than re-proving the dependency's generic specification.

## Simplify prose with the code

Comments and docs are maintained surface area. Remove code-restating or remotely owned explanations while preserving local behavior, timing, ownership, and failure obligations. Keep each doc at its owning level; implementation details and rare cases earn space when they change a maintained contract. Update affected READMEs, API comments, user-visible catalogs, configuration, snapshots, and generated files with their owning change.

## Record proposals and inline notes

Follow the repo's convention for durable design records when one exists; otherwise deliver proposals in the survey report. Consolidate a candidate into its existing owner when it represents the same decision. A substantial proposal contains:

- **Problem:** current surface, files, effective producer/consumer evidence, and maintenance cost, separating production consumers from tests and docs.
- **Proposal:** exactly what to remove, fold, demote, or rehome, including associated tests, docs, snapshots, and generated files; name what remains.
- **Alternatives considered:** the strongest reason to keep the design, smaller changes, and the capability each alternative gives up.
- **Acceptance criteria:** observable end state and verification of retained behavior.
- **Risks:** API and behavior changes, compatibility, plausible future needs, and why the trade-off holds.

Use the repo's implemented-decision format once work ships. Reserve inline TODO/FIXME/XXX for small, local cleanups under the repo's urgency conventions. If no convention exists, use a stable tag such as `TODO(unused-default)` with the evidence and concrete simplifying action. Speculative or design-level ideas earn a proposal or nothing.

## Retire superseded design records

Check for overlap and supersession in the records relevant to a new proposal. Audit beyond that scope only when the user asks to reduce the record set or an implemented change obsoletes an owning record. Follow [superseding records](superseding-records.md) for full versus partial supersession, the added-then-removed case, and retirement. Preserve current durable, wire, compatibility, and rejected-alternative obligations, and honor the repo's retention and frozen-archive policy.

## Fold ideas from another branch

Compare the sibling branch's independent diff against the target base, not against the current branch. Port supported non-overlapping proposals, consolidate overlapping rationale, and count duplicates and low-confidence items honestly. Closing another PR requires authorization or clear ownership of that housekeeping.

## Validate and report

Run the repo's applicable checks for the actual edits: doc and link validators for records, skill validators for skill changes, and relevant lint, tests, generation, or build checks for implementation. Report only commands actually run and their results.

Account for surveyed areas and intentional exclusions, supported candidates, meaningful rejections or deferrals, inline notes, and records added, consolidated, retained, or removed. When records retire, name the old and current owners and the supersession evidence. Keep a PR in draft while the survey expands; mark it ready once candidates, review responses, and validation settle. Describe search coverage accurately rather than claiming an unverified search was exhaustive.
