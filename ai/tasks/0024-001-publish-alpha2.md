# 0024-001 Publish Alpha.2

Status: in-progress
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
- [ ] 0024-001.3 Validate the release preparation commit and publish its exact tag.
- [ ] 0024-001.4 Run exact-alpha.2 macOS/Linux consumer validation and record resolver evidence.

Architecture impact:

- No runtime changes in this release task; operational work remains separate.

Public API impact:

- Publish the already validated 0023 API set. Swift tools minimum 6.3 is explicit.

AIDEV updates required:

- Release readiness, changelog, README/install docs, roadmap, registry, and migration notes.

Validation:

- Prior candidate 7d56798 passed eight jobs in run 36209852394.
- Release preparation is separately validated before tagging; exact release consumption is validated afterward.

Notes:

- User authorized publication as priority one on 2026-09-26. No additional approval is required.
