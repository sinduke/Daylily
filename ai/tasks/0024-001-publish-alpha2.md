# 0024-001 Publish Alpha.2

Status: implemented
Epic: 0024-release-and-operational-readiness

Goal:

- Publish the completed reliability capabilities as an installable alpha.2 and verify exact release consumption.

Scope:

- Versioned changelog, installation examples, migration guide, release notes, annotated tag, GitHub prerelease, and exact-tag CI.

Non-goals:

- Including the following operational-readiness implementation in alpha.2.

Steps:

- [x] 0024-001.1 Verify the prior exact-candidate eight-job CI and clean release base.
- [x] 0024-001.2 Prepare versioned notes, installation examples, and migration guidance.
- [x] 0024-001.3 Validate the release preparation commit and publish its exact tag.
- [x] 0024-001.4 Run exact-alpha.2 macOS/Linux consumer validation and record resolver evidence.

Architecture impact:

- No runtime changes in this release task; operational work remains separate.

Public API impact:

- Publish the already validated 0023 API set. Swift tools minimum 6.3 is explicit.

AIDEV updates required:

- Release readiness, changelog, README/install docs, roadmap, registry, and migration notes.

Validation:

- Prior candidate 7d56798 passed eight jobs in run 36209852394.
- Preparation commit `f0d53421981e42e423e0b53b4f6a5dc3460bec81` passed all eight jobs in [run 36211564375](https://github.com/sinduke/Daylily/actions/runs/36211564375) before tagging.
- Annotated `0.1.0-alpha.2` tag and [GitHub prerelease](https://github.com/sinduke/Daylily/releases/tag/0.1.0-alpha.2) were published from that commit.
- Exact-tag [run 36212096436](https://github.com/sinduke/Daylily/actions/runs/36212096436) passed all ten macOS/Linux core/path/revision/legacy/release jobs.
- Downloaded release resolver records for consumer, template and commerce on both platforms all resolve version `0.1.0-alpha.2` and revision `f0d53421981e42e423e0b53b4f6a5dc3460bec81`. Generated OpenAPI HTTP smoke also passed on both platforms.

Notes:

- User authorized publication as priority one on 2026-09-26. No additional approval is required.
