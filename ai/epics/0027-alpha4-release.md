# 0027 Alpha.4 Release

Status: in-progress

Goal:

- Publish the validated alpha.4 capabilities with migration guidance and verify exact-version consumption on macOS/Linux.

Tasks:

- 0027-001: Versioned changelog, installation/template defaults, migration, preparation CI, immutable annotated tag, GitHub prerelease and exact-version evidence.

Execution:

- The user explicitly authorized publication after completion of 0026. Candidate `1f8e0ea5f149b09cc398d302bf37c5cd63258452` passed 12/12 CI jobs and the independently audited one-hour Linux trial; `049051d` adds only closure docs/evidence.
- Prepare release metadata and the template dependency version, commit for exact-source CI, and tag only after the full preparation matrix passes. Post-publication exact-tag validation adds both release suites for 14 jobs. Keep prior tags and historical trials immutable.
- Runtime, tests, validation scripts and dependency locks remain unchanged. Existing one-hour and real AI evidence is retained at its original source; no new long soak or model trial is required for publication metadata.
