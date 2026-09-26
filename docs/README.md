# Daylily Documentation

Daylily is an experimental AI-first Swift web framework built around Swift Concurrency, explicit runtime contracts, and AI-readable project documentation.

This directory contains beta-facing docs: practical guides for trying the current framework and evaluating what is implemented today.

## Design Principle

Daylily provides default paths, not mandatory paths. Runtime APIs are first-class, macros are convenience syntax, and helpers such as `Dependencies` support common application shapes without replacing a project's own composition root.

## Start Here

- [Quick Start](quickstart.md): install, build, test, run, and validate external package consumption.
- [Capability Matrix](capability-matrix.md): current features, MVP surfaces, and planned work.
- [Alpha.3 migration](migration-alpha3.md): default request deadlines, bounded shutdown and optional transfer observation.
- [Alpha.2 migration](migration-alpha2.md): toolchain, response bodies, lifecycle, and optional inputs.
- [Release Readiness](release-readiness.md): CI, changelog, tag strategy, and known release limits.
- [Vapor 5 Beta Review](vapor5-beta-review.md): source-backed comparison and recommended follow-up priorities.
- [Minimal App Template](../templates/minimal-app/README.md): recommended external project shape.

## Examples

- [Commerce API](examples/commerce-api.md): first real API example with products, orders, state, dependencies, metadata, and tests.
- [Dependencies](examples/dependencies.md): `makeApplication` pattern, test overrides, custom service wiring, typed-key lookup, macro `@Dependency`, and managed service lifecycle design.
- [Swift HTTP Types](examples/http-types.md): optional `DaylilyHTTPTypes` adapter and lossless HTTP boundary rules.
- [Swift OpenAPI Generator Transport](examples/openapi-transport.md): optional `DaylilyOpenAPITransport` adapter for generated server handlers.
- [JSON API](examples/json-api.md): request decoding, JSON responses, and macro `@Body` input.
- [Middleware](examples/middleware.md): application/group/route middleware, observability, and one-shot body rules.
- [Reliability and streaming](reliability-and-streaming.md): current-checkout streaming, lifecycle, OpenAPI, and optional input contracts.
- [Operational readiness](operational-readiness.md): request deadlines, graceful drain, transfer observation and a real container deployment trial.
- [Contract and AI regression](contract-and-ai-regression.md): generated-client compatibility and repeated actual model edits.
- [Testing](examples/testing.md): transport-free tests with `DaylilyTesting`.

## Deeper Project Docs

- [AIDEV](../AIDEV.md): AI development entry point.
- [Project Map](../ai/aidev/project-map.md): modules and file responsibilities.
- [Runtime Contracts](../ai/aidev/runtime-contracts.md): guarantees and extension points.
- [API Registry](../ai/aidev/api-registry.md): current public API surface.
- [Changelog](../CHANGELOG.md): release notes.

## Current Support

- Swift tools version: Swift 6.3; validation toolchain: Swift 6.3.2.
- Platform declared by the package today: macOS 14+.
- CI validation: macOS and Linux.
- External consumer and template validation: fresh SwiftPM packages in path, exact revision, and exact release modes.
- Example validation: commerce API, actual generated OpenAPI client/server, and fixed application-change exercises.
- Transport: NIO-backed HTTP/1.1.
- Status: experimental package-consumer work for the alpha.3 release.
