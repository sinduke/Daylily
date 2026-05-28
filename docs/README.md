# Daylily Documentation

Daylily is an experimental AI-first Swift web framework built around Swift Concurrency, explicit runtime contracts, and AI-readable project documentation.

This directory contains beta-facing docs: practical guides for trying the current framework and evaluating what is implemented today.

## Design Principle

Daylily provides default paths, not mandatory paths. Runtime APIs are first-class, macros are convenience syntax, and helpers such as `Dependencies` support common application shapes without replacing a project's own composition root.

## Start Here

- [Quick Start](quickstart.md): install, build, test, run, and validate external package consumption.
- [Capability Matrix](capability-matrix.md): current features, MVP surfaces, and planned work.
- [Release Readiness](release-readiness.md): CI, changelog, tag strategy, and known release limits.
- [Minimal App Template](../templates/minimal-app/README.md): recommended external project shape.

## Examples

- [Commerce API](examples/commerce-api.md): first real API example with products, orders, state, dependencies, metadata, and tests.
- [JSON API](examples/json-api.md): request decoding, JSON responses, and macro `@Body` input.
- [Middleware](examples/middleware.md): application/group/route middleware, observability, and one-shot body rules.
- [Testing](examples/testing.md): transport-free tests with `DaylilyTesting`.

## Deeper Project Docs

- [AIDEV](../AIDEV.md): AI development entry point.
- [Project Map](../ai/aidev/project-map.md): modules and file responsibilities.
- [Runtime Contracts](../ai/aidev/runtime-contracts.md): guarantees and extension points.
- [API Registry](../ai/aidev/api-registry.md): current public API surface.
- [Changelog](../CHANGELOG.md): release notes.

## Current Support

- Swift tools version: Swift 6.0.
- Platform declared by the package today: macOS 14+.
- CI validation: macOS and Linux.
- External consumer validation: fresh SwiftPM package in path and release modes.
- Template validation: minimal app template in path and release modes.
- Example validation: commerce API example in current checkout path mode.
- Transport: NIO-backed HTTP/1.1.
- Status: experimental package-consumer work after the first alpha release.
