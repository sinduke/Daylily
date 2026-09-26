#!/usr/bin/env python3
"""Run a scoped, loopback-only Linux/Caddy trial; preserve JSON evidence and logs."""
import argparse
import concurrent.futures
import hashlib
import http.client
import json
import pathlib
import shutil
import socket
import statistics
import subprocess
import tempfile
import time
import uuid

ROOT = pathlib.Path(__file__).resolve().parents[1]
SWIFT_IMAGE = "swift:6.3.2-noble"
CADDY = "caddy@sha256:6aeddd44c3078b0f9a35206472a11420648a79c184603ef95957d0a20044cb2b"


def command(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, capture_output=True, **kwargs).stdout.strip()


def request(port, path, method="GET", body=None, timeout=6):
    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=timeout)
    try:
        headers = {"Content-Type": "application/json"} if body is not None else {}
        connection.request(method, path, body=body, headers=headers)
        response = connection.getresponse()
        data = response.read()
        assert response.status == 200, (path, response.status, data)
        return data
    finally:
        connection.close()


def eventually(predicate, timeout=10):
    deadline = time.monotonic() + timeout
    last = None
    while time.monotonic() < deadline:
        try:
            if predicate():
                return
        except (OSError, http.client.HTTPException, AssertionError) as error:
            last = error
        time.sleep(0.05)
    raise AssertionError(f"condition did not become true: {last}")


def first_event(response):
    assert response.status == 200, response.status
    assert response.getheader("Content-Type", "").startswith("text/event-stream")
    while line := response.readline():
        if line.startswith(b"data:"):
            return line
    raise AssertionError("SSE ended before its first event")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--duration", type=int, default=300, help="sustained traffic seconds (default 300)")
    parser.add_argument("--artifacts", type=pathlib.Path, required=True, help="new or empty evidence directory")
    parser.add_argument("--skip-build", help="use an already built trial image")
    options = parser.parse_args()
    if not 1 <= options.duration <= 86400:
        parser.error("duration must be between 1 and 86400 seconds")
    evidence = options.artifacts.resolve()
    if evidence.exists() and any(evidence.iterdir()):
        parser.error("artifacts directory must be new or empty")
    evidence.mkdir(parents=True, exist_ok=True)
    prefix = "daylily-trial-" + uuid.uuid4().hex[:10]
    containers = []
    image = options.skip_build or prefix + ":local"
    result = {"duration_requested_seconds": options.duration, "checks": {}, "result": "running",
              "revision": command("git", "-C", str(ROOT), "rev-parse", "HEAD"),
              "working_tree_dirty": bool(command("git", "-C", str(ROOT), "status", "--porcelain")),
              "docker_version": command("docker", "version", "--format", "{{.Server.Version}}")}
    started = time.monotonic()
    network_created = False
    try:
        # BuildKit may keep FROM layers only in its cache, without a local image tag.
        # Pull explicitly so clean CI hosts can inspect the same toolchain image.
        command("docker", "pull", SWIFT_IMAGE)
        if not options.skip_build:
            with tempfile.TemporaryDirectory(prefix="daylily-build-") as directory:
                context = pathlib.Path(directory)
                shutil.copy2(ROOT / "Package.swift", context / "Package.swift")
                shutil.copytree(ROOT / "Sources", context / "Sources")
                shutil.copytree(ROOT / "Tests", context / "Tests")
                shutil.copytree(ROOT / "examples/deployment-trial", context / "examples/deployment-trial",
                                ignore=shutil.ignore_patterns(".build", ".swiftpm"))
                digest = hashlib.sha256()
                for path in sorted(context.rglob("*")):
                    if path.is_file():
                        digest.update(str(path.relative_to(context)).encode())
                        digest.update(path.read_bytes())
                result["source_tree_sha256"] = digest.hexdigest()
                with (evidence / "build.log").open("w") as log:
                    subprocess.run(["docker", "build", "-f", "examples/deployment-trial/Dockerfile",
                                    "-t", image, str(context)], stdout=log, stderr=subprocess.STDOUT, check=True)
        command("docker", "pull", CADDY)
        (evidence / "Package.resolved").write_text(command("docker", "run", "--rm", "--entrypoint", "cat", image,
                                                         "/usr/local/share/daylily/Package.resolved") + "\n")
        result["swift_version"] = command("docker", "run", "--rm", "--entrypoint", "swift", image, "--version")
        image_records = command("docker", "image", "inspect", image, CADDY, SWIFT_IMAGE, "--format", "{{json .}}")
        result["images"] = [json.loads(line) for line in image_records.splitlines()]
        # Keep only reproducibility metadata, not Docker's full runtime configuration.
        result["images"] = [{"id": item["Id"], "digests": item.get("RepoDigests", []),
                              "architecture": item["Architecture"], "os": item["Os"]} for item in result["images"]]
        command("docker", "network", "create", prefix)
        network_created = True
        backend_ports = {}
        for replica in ("a", "b"):
            name = prefix + "-" + replica
            containers.append(name)
            command("docker", "run", "-d", "--name", name, "--network", prefix, "--network-alias", replica,
                    "-p", "127.0.0.1::8080", "-e", "TRIAL_HOST=0.0.0.0", "-e", "TRIAL_INSTANCE=" + replica, image)
            backend_ports[replica] = int(command("docker", "port", name, "8080/tcp").rsplit(":", 1)[1])
            eventually(lambda r=replica: json.loads(request(backend_ports[r], "/health"))["instance"] == r)

        config = evidence / "proxy"
        config.mkdir()

        def configure(policy):
            (config / "Caddyfile").write_text("{\n admin localhost:2019\n auto_https off\n}\n:8080 {\n"
                " reverse_proxy a:8080 b:8080 {\n"
                f"  lb_policy {policy}\n"
                "  lb_try_duration 2s\n  lb_try_interval 50ms\n"
                "  health_uri /health\n  health_interval 250ms\n  health_timeout 250ms\n"
                " }\n}\n")

        configure("round_robin")
        proxy = prefix + "-proxy"
        containers.append(proxy)
        command("docker", "run", "-d", "--name", proxy, "--network", prefix, "-p", "127.0.0.1::8080",
                "-v", str(config) + ":/etc/caddy:ro", CADDY)
        port = int(command("docker", "port", proxy, "8080/tcp").rsplit(":", 1)[1])
        eventually(lambda: bool(request(port, "/health")))
        instances = {json.loads(request(port, "/health"))["instance"] for _ in range(12)}
        assert instances == {"a", "b"}, instances
        payload = json.loads(request(port, "/tasks/normalize", "POST", '{"text":" Daylily "}'))
        assert payload["normalized"] == "daylily"
        result["checks"]["api_and_two_replicas"] = True

        # SSE remains live longer than the two-second inbound request timeouts.
        connection = http.client.HTTPConnection("127.0.0.1", port, timeout=6)
        mark = time.monotonic()
        connection.request("GET", "/tasks/trial/events?steps=7&interval=500")
        response = connection.getresponse()
        assert response.status == 200 and response.getheader("Content-Type", "").startswith("text/event-stream")
        arrivals = []
        while line := response.readline():
            if line.startswith(b"data:"):
                arrivals.append(time.monotonic() - mark)
        connection.close()
        assert len(arrivals) == 7 and arrivals[0] < 1.5 and arrivals[-1] >= 2.5, arrivals
        result["checks"]["incremental_sse_seconds"] = arrivals

        def snapshots():
            return [json.loads(request(value, "/metrics")) for value in backend_ports.values()]

        def no_streams():
            return all(value["activeStreams"] == 0 for value in snapshots())

        cancelled_before = sum(value["cancelled"] for value in snapshots())
        connection = http.client.HTTPConnection("127.0.0.1", port, timeout=6)
        connection.request("GET", "/tasks/disconnect/events?steps=10000&interval=100")
        response = connection.getresponse()
        first_event(response)
        response.close()
        connection.close()
        eventually(lambda: no_streams() and sum(value["cancelled"] for value in snapshots()) > cancelled_before, timeout=3)
        result["checks"]["disconnect_releases_producer"] = True

        before = sum(value["bytesSent"] for value in snapshots())
        with socket.create_connection(("127.0.0.1", port), timeout=5) as peer:
            peer.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 4096)
            peer.sendall(b"GET /burst?chunks=4096 HTTP/1.1\r\nHost: localhost\r\n\r\n")
            time.sleep(0.4)
            assert any(value["activeStreams"] > 0 for value in snapshots()), "producer ran ahead of slow reader"
        eventually(no_streams)
        delta = sum(value["bytesSent"] for value in snapshots()) - before
        assert delta < 4096 * 65536, delta
        result["checks"]["slow_reader_flushed_bytes_before_cancel"] = delta

        for label, data in (("header", b"GET /health HTTP/1.1\r\nHost:"),
                            ("upload", b"POST /upload HTTP/1.1\r\nHost: localhost\r\nContent-Length: 16\r\n\r\nx")):
            with socket.create_connection(("127.0.0.1", backend_ports["a"]), timeout=5) as peer:
                peer.sendall(data)
                mark = time.monotonic()
                received = b""
                try:
                    while chunk := peer.recv(4096):
                        received += chunk
                except ConnectionResetError:
                    pass
                elapsed = time.monotonic() - mark
                assert 1.5 <= elapsed < 4.5, (label, elapsed)
                # Timeouts close the connection; a transport may optionally send 408 first.
                assert not received or received.startswith(b"HTTP/1.1 408"), (label, received[:100])
                result["checks"][label + "_timeout_seconds"] = elapsed

        # New traffic fails over to b while a drains a short request and a long SSE.
        configure("first")
        command("docker", "exec", proxy, "caddy", "reload", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile")
        eventually(lambda: json.loads(request(port, "/health"))["instance"] == "a")
        connection = http.client.HTTPConnection("127.0.0.1", port, timeout=6)
        connection.request("GET", "/tasks/draining/events?steps=1000&interval=100")
        response = connection.getresponse()
        first_event(response)
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
            short = executor.submit(request, port, "/slow?ms=700")
            time.sleep(0.15)
            mark = time.monotonic()
            command("docker", "kill", "--signal", "TERM", prefix + "-a")
            health = [json.loads(request(port, "/health"))["instance"] for _ in range(12)]
            completed = json.loads(short.result())
            assert completed == {"instance": "a", "status": "completed"}, completed
            assert "b" in health, health
            try:
                while response.readline():
                    assert time.monotonic() - mark < 5, "SSE did not stop at drain deadline"
            except (http.client.IncompleteRead, ConnectionResetError):
                pass
            connection.close()
            assert command("docker", "wait", prefix + "-a", timeout=8) == "0"
            result["checks"]["rolling_drain_seconds"] = time.monotonic() - mark
            assert 1.5 <= result["checks"]["rolling_drain_seconds"] < 5
        old_log = command("docker", "logs", prefix + "-a")
        assert old_log.count("LIFECYCLE instance=a shutdown") == 1
        assert old_log.count("LIFECYCLE instance=a cleanup") == 1
        (evidence / "a-before-restart.log").write_text(old_log)
        command("docker", "start", prefix + "-a")
        # Dynamic host-port bindings can change when the container restarts.
        backend_ports["a"] = int(command("docker", "port", prefix + "-a", "8080/tcp").rsplit(":", 1)[1])
        eventually(lambda: json.loads(request(backend_ports["a"], "/health"))["instance"] == "a")
        configure("round_robin")
        command("docker", "exec", proxy, "caddy", "reload", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile")
        eventually(lambda: {json.loads(request(port, "/health"))["instance"] for _ in range(8)} == {"a", "b"})
        result["checks"]["rolling_restart"] = True

        # Failure occurs after a 200 header; transport records it separately.
        connection = http.client.HTTPConnection("127.0.0.1", port, timeout=6)
        connection.request("GET", "/failure")
        response = connection.getresponse()
        assert response.status == 200
        try:
            response.read()
        except (http.client.IncompleteRead, ConnectionResetError):
            pass
        connection.close()
        eventually(lambda: any(value["failed"] > 0 for value in snapshots()))
        result["checks"]["producer_failure_observed"] = True

        result["resources_before"] = command("docker", "stats", "--no-stream", "--format", "{{json .}}", *containers)
        load_start = time.monotonic()
        deadline = load_start + options.duration

        def worker(number):
            latencies, failures = [], []
            count = 0
            while time.monotonic() < deadline:
                mark = time.monotonic()
                try:
                    if count % 10 == 0:
                        data = request(port, f"/tasks/load{number}/events?steps=3&interval=20")
                        assert data.count(b"data:") == 3
                    elif count % 10 == 1:
                        assert json.loads(request(port, "/tasks/normalize", "POST", '{"text":" LOAD "}'))["normalized"] == "load"
                    else:
                        request(port, "/health")
                    latencies.append(time.monotonic() - mark)
                except Exception as error:
                    failures.append(repr(error))
                count += 1
                time.sleep(0.025)
            return latencies, failures

        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
            loads = list(executor.map(worker, range(4)))
        latencies = sorted(value for values, _ in loads for value in values)
        failures = [value for _, values in loads for value in values]
        result["sustained"] = {"seconds": time.monotonic() - load_start, "workers": 4,
                               "requests_succeeded": len(latencies), "failures": failures,
                               "p50_ms": statistics.median(latencies) * 1000 if latencies else None,
                               "p95_ms": latencies[min(len(latencies) - 1, int(len(latencies) * .95))] * 1000 if latencies else None}
        assert not failures, failures[:5]
        eventually(no_streams)
        result["metrics_after"] = snapshots()
        result["resources_after"] = command("docker", "stats", "--no-stream", "--format", "{{json .}}", *containers)
        result["result"] = "passed"
    except BaseException as error:
        result["result"] = "failed"
        result["error"] = repr(error)
        raise
    finally:
        cleanup_errors = []

        def cleanup(*args):
            try:
                outcome = subprocess.run(args, text=True, capture_output=True, timeout=15)
                if outcome.returncode:
                    cleanup_errors.append({"command": list(args), "error": outcome.stderr[-1000:]})
            except Exception as error:
                cleanup_errors.append({"command": list(args), "error": repr(error)})

        for name in reversed(containers):
            if subprocess.run(["docker", "inspect", name], capture_output=True).returncode:
                continue
            cleanup("docker", "stop", "-t", "8", name)
            log_path = evidence / (name + ".log")
            with log_path.open("w") as log:
                outcome = subprocess.run(["docker", "logs", name], stdout=log, stderr=subprocess.STDOUT)
                if outcome.returncode:
                    cleanup_errors.append({"command": ["docker", "logs", name], "error": "log collection failed"})
            with log_path.open() as log:
                if any("Cannot schedule tasks on an EventLoop" in line for line in log):
                    result["result"] = "failed"
                    result["error"] = "stopped event loop scheduling found in container log"
            cleanup("docker", "rm", "-f", name)
        if network_created:
            cleanup("docker", "network", "rm", prefix)
        if not options.skip_build:
            if subprocess.run(["docker", "image", "inspect", image], capture_output=True).returncode == 0:
                cleanup("docker", "image", "rm", image)
        result["cleanup_errors"] = cleanup_errors
        if cleanup_errors:
            result["result"] = "failed"
        result["total_seconds"] = time.monotonic() - started
        (evidence / "results.json").write_text(json.dumps(result, indent=2) + "\n")
        print(json.dumps({"result": result["result"], "artifacts": str(evidence)}, indent=2))
    return 0 if result["result"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
