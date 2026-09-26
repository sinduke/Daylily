# 0025-001 Publish Alpha.3

Status: implemented
Epic: 0025-alpha3-release

Goal:

- Make the completed operational capabilities installable through exact `0.1.0-alpha.3` and verify the published dependency on both platforms.

Scope:

- Changelog/migration/release notes, installation defaults, operational API consumer checks, release contract CI, annotated tag, GitHub prerelease and resolver evidence.

Non-goals:

- Changing runtime behavior, moving existing tags, stable/beta claims, paid infrastructure or additional AI trials.

Steps:

- [x] 0025-001.1 Verify clean release base, existing tags and the successful 3bad369 integration matrix.
- [x] 0025-001.2 Prepare release/migration docs and operational consumer checks.
- [x] 0025-001.3 Pass complete CI for the release preparation commit.
- [x] 0025-001.4 Publish the exact annotated alpha.3 tag and GitHub prerelease.
- [x] 0025-001.5 Pass exact-tag macOS/Linux release validation and verify resolver records.
- [x] 0025-001.6 Record evidence, synchronize release status and leave a clean pushed tree.

Architecture impact:

- No runtime/module changes. External consumers explicitly exercise the existing operational APIs; exact-release CI gains the existing generated-client contract regression.

Public API impact:

- Publish the 0024 configuration and response-transfer observation APIs without further changes.

AIDEV updates required:

- Changelog, bilingual README, migration/release/operational guides, task/epic, roadmap, workflow and registry.

Validation:

- Base candidate `3bad369331e05231a0c644f148cb59be5f7dc898` passed [all nine jobs](https://github.com/sinduke/Daylily/actions/runs/36212918755); follow-up ad37c64 is documentation-only.
- New consumer changes are validated before the preparation commit is tagged. Exact release version/revision pins are checked after publication.

Notes:

- Explicit user authorization: “发布一下吧”. The next unused prerelease is alpha.3; alpha.1 and alpha.2 remain immutable.

Preparation evidence:

- `scripts/consumer-smoke-test.sh --mode path --profile current --workdir /tmp/daylily-alpha3-consumer-20260926 --keep` passed all eight external tests, macro HTTP and the expected optional-Path compilation diagnostic.
- Three added external checks cover Duration defaults/custom/nil, all observer adapters, and actual HTTP transfer events through both Application.run overloads and both ServiceLifecycle construction paths. The legacy profile remains unchanged.
- Existing generated-client contract regression is now included for exact release consumption as well as path/revision suites.
- Independent migration review confirmed the changed defaults also affect ordinary app.run() calls; nil/zero and best-effort observation boundaries are explicit. Historical trial/release evidence is preserved.
- Shell syntax, YAML parsing and diff whitespace checks passed. External compilation showed an existing NIO ChannelHandlerContext Sendable warning; no compiler errors or stopped-event-loop scheduling warning. Runtime code is unchanged in this release task.

Publication evidence:

- Preparation `cfa835792cca3cce614999ddc7adca290015a801` passed [all nine jobs](https://github.com/sinduke/Daylily/actions/runs/36216710327). Downloaded Linux revision artifacts show all five consumers resolve that commit, eight external tests pass, and all four generated-client HTTP scenarios pass.
- Annotated `0.1.0-alpha.3` tag was pushed at that exact commit; the [GitHub prerelease](https://github.com/sinduke/Daylily/releases/tag/0.1.0-alpha.3) is published, not a draft. Prior tags are unchanged.
- Exact-tag [run 36217281415](https://github.com/sinduke/Daylily/actions/runs/36217281415) passed all 11 jobs with the same candidate SHA and the explicit alpha.3 release_version input.

Final release verification:

- Downloaded macOS/Linux exact-release artifacts each contain five Package.resolved files; all ten prove version `0.1.0-alpha.3` and revision `cfa835792cca3cce614999ddc7adca290015a801` for consumer/template/commerce/OpenAPI/contract packages.
- Both release consumer logs confirm eight passing tests, including new Duration/observer APIs and four actual HTTP server entry points. Both contract logs confirm all four old/new generated-client scenarios pass.
- Candidate gate: 9/9 jobs; exact-tag gate: 11/11 jobs. Release notes link both runs and describe the changed defaults and alpha limitations.
- Final follow-up changes are documentation and registry only. Runtime, tests, validation scripts and CI remain exactly those in the published tag; previous tags remain unchanged.
