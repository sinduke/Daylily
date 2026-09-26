# 0025 Alpha.3 Release

Status: in-progress

Goal:

- Publish the validated operational increment as `0.1.0-alpha.3` and prove exact-version consumption.

Tasks:

- 0025-001: Release notes/migration, current-profile operational API checks, candidate CI, annotated tag/prerelease, exact release CI and resolver evidence.

Delivery:

- The user explicitly requested publication after completion of 0024.
- Runtime candidate 3bad369 passed all nine CI jobs. Preserve alpha.1/alpha.2 tags and make no unrelated runtime changes.
- Keep prerelease status and Swift 6.3 minimum explicit. Installation examples move to alpha.3; old evidence stays historical.
