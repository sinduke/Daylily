# 0025-001 Publish Alpha.3

Status: in-progress
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
- [ ] 0025-001.3 Pass complete CI for the release preparation commit.
- [ ] 0025-001.4 Publish the exact annotated alpha.3 tag and GitHub prerelease.
- [ ] 0025-001.5 Pass exact-tag macOS/Linux release validation and verify resolver records.
- [ ] 0025-001.6 Record evidence, synchronize release status and leave a clean pushed tree.

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
