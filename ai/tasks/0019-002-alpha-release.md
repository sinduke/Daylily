# 0019-002 Alpha Release

Status: implemented
Epic: 0019-release-hygiene

Goal:

- Fix the Linux CI portability issue found after release hygiene.
- Prepare and publish the first SwiftPM alpha release, `0.1.0-alpha.1`.
- Keep README, quickstart, changelog, and AIDEV release state aligned.

Scope:

- Replace the Darwin-only signal import with cross-platform `Darwin` / `Glibc` imports.
- Add SwiftPM package installation instructions for the alpha tag.
- Move changelog content into the `0.1.0-alpha.1` section.
- Tag only after macOS and Linux GitHub Actions pass.
- Create a GitHub Release for the tag.

Non-goals:

- Claim beta or production stability.
- Add runtime features beyond Linux CI compatibility.
- Publish separate binary artifacts.

Validation:

- `git diff --check`
- `swift build`
- `DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test`
- `swift run HelloDaylily --check`
- GitHub Actions macOS and Linux CI
