# Roadmap

## Completed

### 0001 Minimal HTTP Server

Status: implemented

Delivered:

- Swift package skeleton.
- Runtime route DSL.
- `Application.respond(to:)`.
- NIO HTTP transport.
- Default `swift run` server.
- `swift run HelloDaylily --check` behavior checks.
- Basic `Get`, `Post`, and `Group`.
- Path parameter matching.
- 404 behavior.

## AIDEV Foundation

### 0002 AIDEV Project Contract

Status: implemented

Goal:

- Create the project map and AI development rules before adding macro complexity.
- Define architecture boundaries.
- Record current public APIs and parameter conventions.
- Define validation commands and task workflow.

### 0003 AIDEV Self-Contained Spec

Status: implemented

Goal:

- Make AIDEV sufficient for AI handoff without source spelunking.
- Add start-here, concepts, runtime contracts, invariants, playbooks, task protocol, registry expansion, and standard agent prompt.

### 0004 Bilingual README and AI-Native Introduction

Status: implemented

Goal:

- Add a public-facing English README.
- Add a Simplified Chinese README.
- Explain the AI-native development model and how AIDEV helps AI use, upgrade, and extend Daylily.

## Macro Foundation

### 0005 Macro Route MVP

Status: implemented

Goal:

Support:

```swift
@main
@DaylilyServer
struct App {
    @GET("/hello")
    func hello() -> String {
        "Daylily ships."
    }

    @GET("/users/:id")
    func user(req: Request) -> String {
        "User \(req.parameters.id ?? "unknown")"
    }
}
```

Non-goals:

- `@Path`
- `@Body`
- `@GROUP` (completed separately in 0006)
- OpenAPI generation
- DI

The macro should lower into the current runtime route DSL.

### 0006 Group Macro MVP

Status: implemented

Support:

```swift
@GROUP("/api")
struct API {
    @GET("/health")
    func health() -> String { "ok" }
}
```

### 0007 JSON Body and Response

Status: implemented

Delivered:

- `DaylilyJSON` module.
- `request.json(Type.self)` for buffered JSON body decoding.
- `JSON(value)` response wrapper.
- `content-type: application/json` response header.
- Example JSON routes in `HelloDaylily`.
- Behavior checks for JSON response, JSON body, and invalid JSON.

## Recommended Next Feature

### 0008 Streaming Body Model

Status: proposed

Design and implement request body streaming without exposing NIO.

### 0009 Middleware Runtime

Status: proposed

Add middleware pipeline and group/route scoping.

### 0010 Typed Parameter Extraction

Status: proposed

Support:

```swift
func user(@Path id: UUID) async throws -> User
```
