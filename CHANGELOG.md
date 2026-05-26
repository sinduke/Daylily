# Changelog

All notable changes to Daylily will be documented in this file.

Daylily is currently experimental. Public APIs may change before beta or stable release.

## Unreleased

No changes yet.

## 0.1.0-alpha.1 - 2026-05-26

### Added

- Swift Concurrency-first runtime with declarative route DSL.
- NIO-backed HTTP/1.1 server.
- Runtime route metadata and minimal OpenAPI document generation.
- Application, group, and route middleware.
- Request ID and request logging middleware in `DaylilyObservability`.
- Daylily-owned one-shot `RequestBody` model with streaming transport bridge.
- JSON request decoding and `JSON(...)` response helpers.
- Macro route/group MVP with typed `@Path`, `@Query`, `@Header`, and preferred `@Body` JSON body input.
- `@JSONBody` compatibility alias spelling for typed JSON body input.
- `DaylilyTesting` transport-free test helpers.
- AIDEV architecture, registry, task, and playbook documentation for AI-assisted development.
- Beta docs: quickstart, capability matrix, JSON API example, middleware example, and testing example.
- GitHub Actions validation for macOS and Linux.

### Fixed

- Linux build compatibility for DaylilyNIO graceful shutdown signal handling.

### Release Notes

- First public SwiftPM alpha release.
- Public API is still experimental and may change before beta or stable release.
