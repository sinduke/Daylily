# 0023-001 Release and Consumer Validation

Status: implemented
Epic: 0023-reliability-and-streaming

Goal:

- Prove the current package capabilities through identical local-path, exact-revision, and exact-release consumer checks.
- Retain an explicit compatibility check for the published alpha.1 without hiding new capability gaps.
- Make macOS and Linux release evidence reproducible and diagnosable.

Scope:

- Shared smoke helpers and consumer, template, commerce example, and CI integration.
- Independent `--mode path|revision|release|branch` and consumer `--profile current|legacy-alpha1` selectors.
- Exact release requirements and resolved SHA/version assertions, with `dependency-record.json` evidence.
- Optional query/header HTTP checks and a real external compiler diagnostic for optional `@Path`.
- Linux prerequisite installation, prebuilt HTTP executable startup, bounded curl requests, and bounded process cleanup.
- Swift 6.3.2 on macOS 26/Xcode 26.5 and Linux Ubuntu 24.04/official Swift container.
- OpenAPI generator smoke integration from task 0023-003.

Non-goals:

- Publishing a new tag, changing the package dependency policy, or claiming an unavailable historical CI log proves a failure cause.
- Floating toolchains, implicit legacy capability selection from dependency source, or accepting a release range as release proof.

Steps:

- [x] 0023-001.1 Separate source from capabilities and validate exact resolver results.
- [x] 0023-001.2 Harden scratch creation, HTTP startup, diagnostics, and cleanup.
- [x] 0023-001.3 Add a pinned, parallel macOS/Linux validation matrix with candidate and legacy gates.
- [x] 0023-001.4 Validate scripts, real external packages, and reviewed CI configuration.
- [x] 0023-001.5 Integrate shared documentation and record final platform evidence.

Architecture impact:

- No runtime/module boundary changes. `scripts/smoke-common.sh` contains shared validation plumbing.
- CI runs core, path, revision, and legacy suites independently on both platforms; failure in one suite does not skip other evidence.

Public API impact:

- Smoke CLI adds exact revision, capability profile, and optional exact compiler assertion.
- Release mode requires `--version` and uses an exact version. Existing branch mode remains available but is not a release gate.
- `--workdir` now requires a new/empty directory to avoid overwriting or removing caller data.

AIDEV updates required:

- Parent integration owns README, AIDEV, workflow, registry, capability matrix, and release-readiness updates.
- New legacy invocation: `scripts/consumer-smoke-test.sh --mode release --version 0.1.0-alpha.1 --profile legacy-alpha1`.
- Candidate invocation: `scripts/consumer-smoke-test.sh --mode revision --repo-url URL --revision FULL_SHA --profile current`.
- Template and example scripts accept the same dependency-source flags, without a capability profile.
- OpenAPI smoke supports path/revision/release with the full current capability set.

Validation:

- `bash -n` for all affected shell scripts.
- Invalid/missing arguments, nonempty scratch directories, generated manifests, exact pin assertions, and profile selection.
- Current path consumer/template/commerce and legacy exact-release checks using isolated external SwiftPM directories.
- Root build/tests/checks and final Linux/GitHub CI evidence coordinated by parent.

Notes:

- Previous Linux failure was at external consumer smoke on 2026-06-04; logs have expired. A 2026-09-26 local inspection of `swift:6.3.2-noble` confirmed that the image has Git but lacks both curl and Python 3. Explicit installation fixes the observed prerequisite gap; unavailable historical logs prevent assigning a definitive historical root cause.
- Readiness now begins only after both executables are built. HTTP checks have connection and total timeouts and bypass proxy settings for localhost.
- CI candidate uses `file://$GITHUB_WORKSPACE` and the actual checked-out full SHA, exercising Git-source consumption for PR merge commits without requiring an unpublished release or remote branch mutation.
- Optional workflow input `release_version` adds a full current-capability exact-release suite on both platforms after a tag exists.
- macOS runner/Xcode availability verified against https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md on 2026-09-26.
- No commit or push in the delegated slice; parent handles task-level finish.

Validation results (2026-09-26):

- macOS/Xcode 26.5/Swift 6.3.2 current path consumer passed all five external tests, middleware/dependency HTTP assertions, optional query/header missing/present/invalid-value assertions, and the optional `@Path` compiler diagnostic.
- Current path minimal template passed its test and `App --check`; commerce passed four tests and `App --check`.
- Exact `0.1.0-alpha.1` legacy consumer and exact-release minimal template both passed all builds, tests, and checks.
- Exact Git revision template passed against `file:///Users/vicki/Documents/SwiftService/Daylily` at `efce8f5855ebfdcb4662332cbc1081a40b4c7717`, including resolver SHA verification. This checks Git consumption plumbing; full new-capability candidate proof requires the parent integration commit.
- `actionlint` accepted the workflow; `bash -n` and `git diff --check` passed.
- CLI missing values, short SHA, and release without version are rejected. Nonempty scratch directory rejection preserves existing files. SHA/version mismatches are rejected; matching exact pins and renamed local Git URL normalization pass.
- HTTP startup now probes port availability and uses a 30-second readiness deadline. The final HTTP helper was rechecked against the built current consumer. Negative diagnostic checks restore the valid manifest before returning so retained packages still build normally.
- Legacy alpha.1 does not support the generated macro `--port` argument, so its explicit compatibility profile retains build/in-memory checks. Current capability checks always include the same real HTTP tests for path, revision, and release sources.
- Stable script copies were used for the final legacy and revision runs to avoid concurrent source edits changing Bash's input offset. Retained workdirs and full logs are `/tmp/daylily-0023-{current-consumer,current-template,current-commerce,legacy-consumer-final,legacy-template-final,revision-template-final}` and corresponding `.log` files.
- Task 0023-006 AI exercises script uses the shared helper and runs at the end of the CI path suite; its owner verified six tests across three exercise suites.
- Final shared documentation updates and complete Linux/GitHub candidate validation remain parent integration responsibilities; no release tag was created here.

Integration note: implementation, local review, and shared API documentation are complete. The remote exact-candidate release gate is tracked by 0023-007.
