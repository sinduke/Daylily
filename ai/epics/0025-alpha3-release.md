# 0025 Alpha.3 Release

Status: implemented

Goal:

- Publish the validated operational increment as `0.1.0-alpha.3` and prove exact-version consumption.

Tasks:

- 0025-001: Release notes/migration, current-profile operational API checks, candidate CI, annotated tag/prerelease, exact release CI and resolver evidence.

Delivery:

- The user explicitly requested publication after completion of 0024.
- Runtime candidate 3bad369 passed all nine CI jobs. Preserve alpha.1/alpha.2 tags and make no unrelated runtime changes.
- Keep prerelease status and Swift 6.3 minimum explicit. Installation examples move to alpha.3; old evidence stays historical.

Outcome:

- Published `0.1.0-alpha.3` at `cfa835792cca3cce614999ddc7adca290015a801` after all nine preparation jobs passed.
- Exact-tag run 36217281415 passed all 11 jobs; ten release resolver files prove the version and revision, including generated-client contract regression on both platforms.
- Current documentation and installation defaults target alpha.3; previous tags and trial evidence are preserved.
