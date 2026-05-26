# 0013 Observability Middleware

Status: proposed

Purpose:

- Add practical visibility after runtime middleware and lifecycle basics exist.
- Provide logging/tracing/timing foundations without making them mandatory dependencies in `DaylilyCore`.

Recommended tasks:

- `0013-001-request-logging-middleware`
- `0013-002-request-id-and-timing`
- `0013-003-observability-hooks`

Design notes:

- Prefer middleware packages or optional modules over bloating `DaylilyCore`.
- Keep default error output safe.
- Make diagnostics useful for AI agents and humans.

Non-goals for the first task:

- Metrics backend integrations.
- OpenTelemetry dependency.
- Structured logging framework commitment.
- Production dashboard.
