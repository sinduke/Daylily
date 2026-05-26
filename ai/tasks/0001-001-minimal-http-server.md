# 0001-001 Minimal HTTP Server

Status: implemented
Epic: 0001-runtime-foundation

Steps:

- [x] 0001-001.1 Build minimal runtime, server, and checks.

Goal:

- Create a minimal Swift package for Daylily.
- Provide a declarative route runtime.
- Serve HTTP with a NIO-backed transport.
- Include executable checks for exact routes, parameters, groups, and 404s.

Run:

```sh
swift build
swift run HelloDaylily --check
swift run
```

Smoke test:

```sh
curl http://127.0.0.1:8080/hello
```
