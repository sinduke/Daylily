# Release Readiness

Daylily is in experimental beta-closure work. This document tracks what is ready for external trial and what still needs caution.

## Current Release Status

- Package release: not tagged yet.
- Suggested first tag: `0.1.0-alpha.1`.
- Release condition: GitHub Actions must pass on macOS and Linux before tagging.
- Stability: experimental API, suitable for exploration and feedback, not production promises.

## Validation Surface

Local validation:

```sh
swift build
DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test
swift run HelloDaylily --check
```

GitHub Actions validation:

- macOS runner: `macos-latest`
- Linux runner: `ubuntu-latest` with the official `swift:6.3.2-noble` container
- Commands: `swift package resolve`, `swift build`, `swift test`, `swift run HelloDaylily --check`

Linux validation is CI-owned for now. Local development has been verified on macOS with Xcode 26.5 and Swift 6.3.2.

## Ready for External Trial

- Runtime routing and request/response model.
- NIO-backed HTTP/1.1 server.
- Middleware at application, group, and route scope.
- One-shot request body model with streaming transport bridge.
- JSON body decoding and JSON responses.
- Minimal OpenAPI document generation from explicit route metadata.
- Macro route/group MVP and typed handler inputs.
- Transport-free testing helpers.
- AI-readable AIDEV project handoff.
- Beta documentation set.

## Known Limitations

- Public API is still experimental.
- Deep Swift schema derivation is not implemented.
- Dependency injection is not implemented.
- Macro middleware attributes are not implemented.
- Production auth, ORM, queue, realtime, and deployment tooling are future ecosystem work.
- Benchmarks are not published yet.

## Release Checklist

Before creating a tag:

- GitHub Actions passes on macOS and Linux.
- `CHANGELOG.md` has a section for the tag.
- README and docs state the correct support level.
- `ai/aidev/api-registry.md` and `ai/aidev/registry.yml` match public API.
- The tag name follows semver pre-release form, such as `0.1.0-alpha.1`.
