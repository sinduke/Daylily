# API and SSE deployment trial

Independent SwiftPM consumer for [operational readiness](../../docs/operational-readiness.md). It requires the alpha.3 API set. The package defaults to a relative Daylily dependency.

Run locally with Swift 6.3.2:

```sh
swift run --package-path examples/deployment-trial TrialServer
curl http://127.0.0.1:8080/health
curl -N 'http://127.0.0.1:8080/tasks/demo/events?steps=5&interval=500'
curl -H 'content-type: application/json' -d '{"text":" Daylily "}' http://127.0.0.1:8080/tasks/normalize
```

`TRIAL_HOST`, `TRIAL_PORT` and `TRIAL_INSTANCE` override the default loopback host, port 8080 and instance label. Trial timers are deliberately short (two seconds). `/metrics`, `/slow`, `/upload`, `/burst` and `/failure` are local diagnostics; do not expose this example as a production API.

Run two Linux replicas behind Caddy, including rolling restart and scoped cleanup, from the repository root:

```sh
python3 scripts/deployment-trial.py --duration 300 --artifacts /tmp/daylily-deployment
```

The duration is the sustained-request phase, excluding image build and functional checks. Use a new/empty artifact path. Progress streams are finite computations owned by each request, not persistent background jobs.
