# 0012-002 Graceful Shutdown

Status: implemented
Epic: 0012-lifecycle-server-controls

Goal:

- Let the default NIO server close cleanly on process shutdown signals.
- Ensure lifecycle `shutdown` and `cleanup` can run after the server channel closes.
- Keep shutdown mechanics out of user-facing handler APIs.

Scope:

- Add SIGINT/SIGTERM handling inside `DaylilyNIO`.
- Close the server channel on the channel event loop.
- Keep `Application.run` lifecycle order from `0012-001`.
- Smoke test real HTTP server shutdown.
- Update AIDEV docs.

Non-goals:

- Request draining.
- Connection draining timeouts.
- Custom signal lists.
- Multi-server coordination.
- Windows signal handling.

Behavior:

```text
SIGINT/SIGTERM -> close NIO server channel -> NIOHTTPServer.run returns -> Application.run calls shutdown -> cleanup
```

Rules:

- Signal handling is transport-owned in `DaylilyNIO`.
- User-facing APIs do not expose NIO channel types.
- Shutdown signal sources are cancelled when `NIOHTTPServer.run` exits.
- Shutdown is best-effort in this MVP.

Steps:

- [x] 0012-002.1 Install SIGINT/SIGTERM signal sources after bind.
- [x] 0012-002.2 Close the NIO channel on signal.
- [x] 0012-002.3 Smoke test real server shutdown.
- [x] 0012-002.4 Update AIDEV docs.
- [x] 0012-002.5 Review, fix, validate, then finish the task.

Architecture impact:

- Keeps graceful shutdown mechanics in `DaylilyNIO`.
- Uses lifecycle from `0012-001` without changing handler APIs.

Public API impact:

- No new public user-facing API.
- `NIOHTTPServer.run(started:)` behavior now includes default SIGINT/SIGTERM shutdown handling.

AIDEV updates required:

- `ai/aidev/api-registry.md`
- `ai/aidev/runtime-contracts.md`
- `ai/aidev/registry.yml`
- `ai/aidev/roadmap.md`
- `ai/epics/0012-lifecycle-server-controls.md`

Validation:

Required after implementation:

```sh
swift build
swift run HelloDaylily --check
```

Completed validation:

```sh
swift build
swift run HelloDaylily --check
swift run
curl http://127.0.0.1:8080/hello
kill -TERM "$(lsof -ti tcp:8080)"
ruby -e 'require "yaml"; YAML.load_file("ai/aidev/registry.yml"); puts "registry.yml ok"'
git diff --check
```

Suggested checks:

- Server responds before signal.
- SIGTERM closes the server and the `swift run` process exits cleanly.
- `registry.yml` parses.
- `git diff --check` passes.
