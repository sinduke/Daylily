# 0019 Release Hygiene

Status: implemented

Purpose:

- Prepare Daylily for external trial by making CI, release notes, and release readiness explicit.
- Keep support claims conservative while giving users a clear path to evaluate the framework.
- Publish the first alpha tag only after macOS and Linux CI are green.

Tasks:

- `0019-001-release-hygiene` (implemented)
- `0019-002-alpha-release` (implemented)

Required work:

- macOS and Linux GitHub Actions validation.
- `CHANGELOG.md`.
- Release-readiness documentation.
- README and docs support-status updates.
- AIDEV registry and roadmap updates.
- `0.1.0-alpha.1` SwiftPM release after CI validation.

Non-goals:

- Creating a release tag before CI passes.
- Claiming beta or production stability.
- Adding production ecosystem modules.
