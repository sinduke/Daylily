# 0019 Release Hygiene

Status: implemented

Purpose:

- Prepare Daylily for external trial by making CI, release notes, and release readiness explicit.
- Keep support claims conservative while giving users a clear path to evaluate the framework.
- Establish the first alpha tag strategy without creating a tag before CI is green.

Tasks:

- `0019-001-release-hygiene` (implemented)

Required work:

- macOS and Linux GitHub Actions validation.
- `CHANGELOG.md`.
- Release-readiness documentation.
- README and docs support-status updates.
- AIDEV registry and roadmap updates.

Non-goals:

- Creating a release tag before CI passes.
- Publishing package release artifacts.
- Adding production ecosystem modules.
