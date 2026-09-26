# 0027-001 Publish Alpha.4

Status: implemented
Epic: 0027-alpha4-release

Goal:

- Publish exact `0.1.0-alpha.4` and complete macOS/Linux release consumption verification.

Scope:

- Migration/release notes, installation/template version, changelog, shared release status, preparation CI, annotated tag, GitHub prerelease and resolver evidence.

Non-goals:

- Runtime changes, moving previous tags, stable/Beta claims, another long soak or additional account-consuming AI trials.

Steps:

- [x] 0027-001.1 Verify clean release base, unused version and successful candidate CI/deployment evidence.
- [x] 0027-001.2 Prepare migration, versioned changelog and current installation/template defaults.
- [x] 0027-001.3 Pass full macOS/Linux CI for the preparation commit.
- [x] 0027-001.4 Publish an annotated alpha.4 tag and GitHub prerelease at that exact commit.
- [x] 0027-001.5 Pass all 14 exact-tag CI jobs and audit the 12 release resolver pins.
- [x] 0027-001.6 Synchronize published status and retain evidence in a clean pushed tree.

Architecture impact:

- None; the template's default Daylily version advances from alpha.3 to alpha.4.

Public API impact:

- Publish the already validated response-write/observation/nullability APIs and independent persistent example, with no new behavior changes.

AIDEV updates required:

- Changelog, bilingual README, quickstart, migration, release/capability guides, roadmap, task/epic and registry.

Validation:

- Candidate `1f8e0ea5f149b09cc398d302bf37c5cd63258452`: [12/12 CI](https://github.com/sinduke/Daylily/actions/runs/36244501153) and [one-hour Linux](https://github.com/sinduke/Daylily/actions/runs/36244505313), independently audited in 0026.
- The preparation matrix must validate its exact committed source before the annotated tag is created. The release matrix must resolve version alpha.4 and that tag's exact revision, including both persistent consumers and generated-client contracts.

Notes:

- Explicit user authorization: “发布”. Alpha.4 was absent from local/remote tags and GitHub releases. Prior alpha.1/2/3 tags are preserved.
- Exact-source CI used a committed preparation snapshot; publication and exact-tag evidence are now complete.
- Historical acceptance retains the original candidate SHA and measured duration; the release does not imply a new one-hour run or a Beta gate completion.

Preparation review:

- Independent review verified version pointers, migration semantics, honest pending publication state and the 14-job/12-release-pin acceptance plan.
- SwiftPM parsed the updated minimal-app manifest successfully. Registry YAML, local Markdown links and whitespace checks passed.
- `git diff 1f8e0ea -- Sources Tests scripts .github Package.swift Package.resolved examples` is empty; the only non-documentation edit is the template's default dependency version. The full preparation matrix validates this exact committed release snapshot.

Publication and verification evidence:

- Preparation `7fc09c4289052355578f007f4ebfb97c9b686430` passed [all 12 jobs](https://github.com/sinduke/Daylily/actions/runs/36249744913) before publication.
- Annotated `0.1.0-alpha.4` points to that exact commit; the [GitHub prerelease](https://github.com/sinduke/Daylily/releases/tag/0.1.0-alpha.4) is published and not a draft. Earlier tags are unchanged.
- [Exact-tag CI](https://github.com/sinduke/Daylily/actions/runs/36250605916) passed all 14 jobs. Both platforms' six release consumers yield 12 matching Package.resolved files plus 10 expected dependency-record.json files at exact version alpha.4 and the tag revision; the OpenAPI smoke records its dependency in Package.resolved only.
- Runtime, tests, harness, CI and dependency locks are unchanged from the validated implementation; final follow-up contains only publication documentation and registry evidence.
- The original one-hour/AI evidence remains attributed to its actual source and protocol. No new one-hour run, additional model trials or Beta certification is implied.
- Durable [publication verification record](../../docs/alpha4-release-verification.md) includes exact resolver pins and artifact inventory hashes.
