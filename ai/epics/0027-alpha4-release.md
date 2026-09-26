# 0027 Alpha.4 Release

Status: implemented

Goal:

- Publish the validated alpha.4 capabilities with migration guidance and verify exact-version consumption on macOS/Linux.

Tasks:

- 0027-001: Versioned changelog, installation/template defaults, migration, preparation CI, immutable annotated tag, GitHub prerelease and exact-version evidence.

Execution:

- The user explicitly authorized publication after completion of 0026. Candidate `1f8e0ea5f149b09cc398d302bf37c5cd63258452` passed 12/12 CI jobs and the independently audited one-hour Linux trial; `049051d` adds only closure docs/evidence.
- Prepare release metadata and the template dependency version, commit for exact-source CI, and tag only after the full preparation matrix passes. Post-publication exact-tag validation adds both release suites for 14 jobs. Keep prior tags and historical trials immutable.
- Runtime, tests, validation scripts and dependency locks remain unchanged. Existing one-hour and real AI evidence is retained at its original source; no new long soak or model trial is required for publication metadata.

Publication and verification evidence:

- Preparation `7fc09c4289052355578f007f4ebfb97c9b686430` passed [all 12 jobs](https://github.com/sinduke/Daylily/actions/runs/36249744913) before publication.
- Annotated `0.1.0-alpha.4` points to that exact commit; the [GitHub prerelease](https://github.com/sinduke/Daylily/releases/tag/0.1.0-alpha.4) is published and not a draft. Earlier tags are unchanged.
- [Exact-tag CI](https://github.com/sinduke/Daylily/actions/runs/36250605916) passed all 14 jobs. Both platforms' six release consumers yield 12 matching Package.resolved files plus 10 expected dependency-record.json files at exact version alpha.4 and the tag revision; the OpenAPI smoke records its dependency in Package.resolved only.
- Runtime, tests, harness, CI and dependency locks are unchanged from the validated implementation; final follow-up contains only publication documentation and registry evidence.
- The original one-hour/AI evidence remains attributed to its actual source and protocol. No new one-hour run, additional model trials or Beta certification is implied.
