#!/usr/bin/env python3
"""Verify a private TLS/API/SSE/Postgres deployment and preserve bounded-run evidence.

This is a paced operational trial, not a throughput benchmark or leak proof.
Requires Docker; creates and cleans only uniquely named resources. The normal
build labels its captured source tree. --skip-build records that an unlabelled
external image cannot be bound to the current source checkout.
"""
import argparse
import concurrent.futures
import contextlib
import datetime
import hashlib
import http.client
import json
import os
import pathlib
import platform
import secrets
import shutil
import socket
import ssl
import statistics
import subprocess
import tempfile
import threading
import time
import uuid

ROOT = pathlib.Path(__file__).resolve().parents[1]
SWIFT_IMAGE = "swift:6.3.2-noble"
CADDY_IMAGE = "caddy@sha256:6aeddd44c3078b0f9a35206472a11420648a79c184603ef95957d0a20044cb2b"
POSTGRES_IMAGE = "postgres:17"
ORDER = {"customerEmail": "trial@example.com", "items": [
    {"productID": 1, "quantity": 2}, {"productID": 3, "quantity": 1}]}
BUDGETS = {"rss_absolute_kib": 512 * 1024, "rss_window_growth_kib": 64 * 1024,
           "idle_fd_growth": 32, "window_samples": 3}


def timestamp():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def command(*args, timeout=30, env=None):
    result = subprocess.run(args, capture_output=True, text=True, timeout=timeout, env=env)
    if result.returncode:
        # Environment values are never included in commands or evidence.
        raise RuntimeError(f"{args[:3]!r} exited {result.returncode}: {result.stderr[-1500:]}")
    return result.stdout.strip()


def require(condition, detail):
    if not condition:
        raise AssertionError(detail)


def eventually(predicate, timeout=20):
    deadline, last = time.monotonic() + timeout, None
    while time.monotonic() < deadline:
        try:
            value = predicate()
            if value:
                return value
        except (OSError, http.client.HTTPException, AssertionError, RuntimeError) as error:
            last = str(error)
        time.sleep(0.1)
    raise AssertionError(f"condition did not become true within {timeout}s: {last}")


def tree_hash(directory):
    digest = hashlib.sha256()
    for path in sorted(directory.rglob("*")):
        if path.is_file():
            digest.update(str(path.relative_to(directory)).encode() + b"\0")
            data = path.read_bytes()
            digest.update(str(len(data)).encode() + b"\0" + data)
    return digest.hexdigest()


def captured_sources(directory):
    for name in ("Package.swift", "Package.resolved"):
        shutil.copy2(ROOT / name, directory / name)
    shutil.copytree(ROOT / "Sources", directory / "Sources")
    shutil.copytree(ROOT / "examples/commerce-api", directory / "examples/commerce-api",
                    ignore=shutil.ignore_patterns(".build", ".swiftpm", "__pycache__"))


def remaining(deadline):
    value = deadline - time.monotonic()
    if value <= 0:
        raise TimeoutError("HTTP request exceeded its total deadline")
    return value


@contextlib.contextmanager
def connection_budget(connection, timeout):
    """A wall-clock budget also interrupts trickled headers and body reads."""
    deadline = time.monotonic() + timeout
    timer = None
    try:
        connection.connect()
        transport = connection.sock

        def expire():
            try:
                transport.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass  # The request may have closed the same socket first.

        timer = threading.Timer(remaining(deadline), expire)
        timer.daemon = True
        timer.start()
        yield transport, deadline
    finally:
        if timer:
            timer.cancel()
            timer.join()
        connection.close()


def response_chunks(response, transport, deadline, limit=256 * 1024):
    """Read available chunks, checking the total budget even for endless SSE."""
    size = 0
    while True:
        transport.settimeout(remaining(deadline))
        chunk = response.read1(8192)
        remaining(deadline)
        if not chunk:
            return
        size += len(chunk)
        require(size <= limit, f"response exceeded {limit} bytes")
        yield chunk


def response_lines(response, transport, deadline):
    pending = b""
    for chunk in response_chunks(response, transport, deadline):
        pending += chunk
        require(len(pending) <= 16 * 1024, "SSE line buffer exceeded 16 KiB")
        while b"\n" in pending:
            line, pending = pending.split(b"\n", 1)
            yield line + b"\n"
    require(not pending, "SSE ended with an incomplete line")


def exchange(port, path, method="GET", body=None, headers=None, context=None, timeout=10):
    connection = (http.client.HTTPSConnection("localhost", port, context=context, timeout=timeout)
                  if context else http.client.HTTPConnection("127.0.0.1", port, timeout=timeout))
    with connection_budget(connection, timeout) as (transport, deadline):
        fields = {"Connection": "close", **(headers or {})}
        if body is not None:
            fields["Content-Type"] = "application/json"
            body = json.dumps(body)
        transport.settimeout(remaining(deadline))
        connection.request(method, path, body=body, headers=fields)
        transport.settimeout(remaining(deadline))
        response = connection.getresponse()
        data = b"".join(response_chunks(response, transport, deadline))
        remaining(deadline)
        return response.status, data


def accepted(port, path, expected=200, **kwargs):
    status, body = exchange(port, path, **kwargs)
    require(status == expected, f"{path}: expected {expected}, received {status}, body={body[:300]!r}")
    return json.loads(body)


def first_event(response, lines):
    require(response.status == 200, f"SSE status {response.status}")
    require(response.getheader("Content-Type", "").startswith("text/event-stream"), "SSE content type")
    for line in lines:
        if line.startswith(b"data:"):
            return line.decode().strip()
    raise AssertionError("SSE ended before its first event")


class Trial:
    def __init__(self, options):
        self.options = options
        self.evidence = options.artifacts.resolve()
        self.prefix = "daylily-sustained-" + uuid.uuid4().hex[:10]
        self.image = options.skip_build or self.prefix + ":local"
        self.containers = []
        self.network_created = self.volume_created = False
        self.password = secrets.token_urlsafe(32)
        self.ports, self.generations = {}, {"a": 0, "b": 0}
        self.restarting = set()
        self.lock = threading.Lock()
        self.phase = "setup"
        self.samples, self.sample_errors, self.load_records = [], [], []
        self.db_windows = []
        self.stop = threading.Event()
        self.started = time.monotonic()
        self.result = {"result": "running", "duration_requested_seconds": options.duration,
                       "checks": {}, "resource_budgets": BUDGETS.copy(), "phases": [],
                       "environment": {"python": platform.python_version(), "host_system": platform.system(),
                                       "host_architecture": platform.machine()},
                       "sample_interval_seconds": 5 if options.duration <= 120 else 15,
                       "limitations": ["Paced mixed traffic, not maximum throughput", "Resource windows are not a leak proof",
                                       "Loopback-published TLS ingress on an isolated Docker network",
                                       "Database TLS disabled only inside the private trial network"]}
        self.progress = threading.Thread(target=self.heartbeat, daemon=True)

    def heartbeat(self):
        while not self.stop.wait(60):
            with self.lock:
                print(json.dumps({"phase": self.phase, "elapsed_seconds": round(time.monotonic() - self.started),
                                  "traffic_requests": len(self.load_records), "resource_samples": len(self.samples)}), flush=True)

    def set_phase(self, phase):
        with self.lock:
            self.phase = phase
            self.result["phases"].append({"phase": phase, "timestamp": timestamp(),
                                          "elapsed_seconds": time.monotonic() - self.started})
        print(json.dumps({"phase": phase, "timestamp": timestamp()}), flush=True)

    def port(self, name, container_port=8080):
        value = command("docker", "port", name, f"{container_port}/tcp")
        require(value.startswith("127.0.0.1:"), f"non-loopback port binding: {value}")
        return int(value.rsplit(":", 1)[1])

    def run_container(self, suffix, *arguments, env=None):
        name = self.prefix + "-" + suffix
        self.containers.append(name)
        command("docker", "run", "-d", "--name", name, "--network", self.prefix, *arguments, env=env)
        return name

    def prepare(self):
        self.result["revision"] = command("git", "-C", str(ROOT), "rev-parse", "HEAD")
        self.result["working_tree_dirty"] = bool(command("git", "-C", str(ROOT), "status", "--porcelain"))
        harness = pathlib.Path(__file__).read_bytes()
        self.result["harness_sha256"] = hashlib.sha256(harness).hexdigest()
        (self.evidence / "executed-harness.py").write_bytes(harness)
        self.result["docker_version"] = command("docker", "version", "--format", "{{.Server.Version}}")
        self.result["topology"] = {"resource_prefix": self.prefix, "replicas": 2,
            "database_pool_max_connections_per_replica": 4, "database_operation_timeout_ms": 1500,
            "shutdown_grace_ms": 2000, "database_tls": "disabled-on-private-network"}
        self.result["ci"] = {key: os.environ.get(key) for key in ("GITHUB_RUN_ID", "GITHUB_SHA", "GITHUB_REPOSITORY")}
        self.result["image_acquisition"] = {}
        for image in (SWIFT_IMAGE, CADDY_IMAGE, POSTGRES_IMAGE):
            cached = subprocess.run(["docker", "image", "inspect", image], capture_output=True).returncode == 0
            if not cached:
                command("docker", "pull", image, timeout=600)
            self.result["image_acquisition"][image] = "local-cache" if cached else "pulled"
        with tempfile.TemporaryDirectory(prefix="daylily-sustained-build-") as directory:
            context = pathlib.Path(directory)
            captured_sources(context)
            self.result["source_tree_sha256"] = tree_hash(context)
            if not self.options.skip_build:
                self.set_phase("image-build")
                arguments = ["docker", "build", "-f", "examples/commerce-api/persistent/Dockerfile", "-t", self.image,
                             "--label", "org.daylily.source-revision=" + self.result["revision"],
                             "--label", "org.daylily.source-tree-sha256=" + self.result["source_tree_sha256"], str(context)]
                with (self.evidence / "build.log").open("w") as log:
                    subprocess.run(arguments, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=3600)
        image_records = []
        for image in (self.image, SWIFT_IMAGE, CADDY_IMAGE, POSTGRES_IMAGE):
            record = json.loads(command("docker", "image", "inspect", image))[0]
            image_records.append({"reference": image, "id": record["Id"], "digests": record.get("RepoDigests", []),
                                  "architecture": record["Architecture"], "os": record["Os"]})
            if image == self.image:
                labels = record.get("Config", {}).get("Labels") or {}
                self.result["image_source_labels"] = {key: labels.get(key) for key in
                    ("org.daylily.source-revision", "org.daylily.source-tree-sha256")}
        self.result["images"] = image_records
        self.result["image_source_verified"] = self.result["image_source_labels"] == {
            "org.daylily.source-revision": self.result["revision"],
            "org.daylily.source-tree-sha256": self.result["source_tree_sha256"]}
        if not self.options.skip_build:
            require(self.result["image_source_verified"], "built image source labels do not match captured source")
        self.result["swift_version"] = command("docker", "run", "--rm", "--entrypoint", "swift", self.image, "--version")
        (self.evidence / "Package.resolved").write_text(command("docker", "run", "--rm", "--entrypoint", "cat", self.image,
            "/usr/local/share/daylily/Package.resolved") + "\n")
        self.set_phase("topology-startup")
        command("docker", "network", "create", self.prefix)
        self.network_created = True
        command("docker", "volume", "create", self.prefix + "-data")
        self.volume_created = True
        self.database = self.run_container("db", "--network-alias", "db", "-e", "POSTGRES_USER=commerce",
            "-e", "POSTGRES_DB=commerce", "-e", "POSTGRES_PASSWORD", "-v",
            self.prefix + "-data:/var/lib/postgresql/data", POSTGRES_IMAGE,
            env={**os.environ, "POSTGRES_PASSWORD": self.password})
        eventually(lambda: command("docker", "exec", self.database, "pg_isready", "-U", "commerce", "-d", "commerce"), timeout=40)
        for replica in ("a", "b"):
            name = self.run_container(replica, "--network-alias", replica, "-p", "127.0.0.1::8080",
                "-e", "PGHOST=db", "-e", "PGUSER=commerce", "-e", "PGDATABASE=commerce", "-e", "PGSSLMODE=disable",
                "-e", "PGPASSWORD", "-e", "PGPOOL_MAX_CONNECTIONS=4", "-e", "DB_OPERATION_TIMEOUT_MS=1500",
                "-e", "SHUTDOWN_GRACE_MS=2000", "-e", "INSTANCE_ID=" + replica, self.image,
                env={**os.environ, "PGPASSWORD": self.password})
            self.ports[replica] = self.port(name)
            eventually(lambda r=replica: accepted(self.ports[r], "/api/ready")["instance"] == r, timeout=40)
        self.config = self.evidence / "Caddyfile"
        self.config.write_text("""{
    admin off
    auto_https disable_redirects
}
https://localhost:8443 {
    tls internal
    reverse_proxy a:8080 b:8080 {
        lb_policy round_robin
        lb_try_duration 5s
        lb_try_interval 50ms
        lb_retry_match method GET
        health_uri /api/health
        health_interval 250ms
        health_timeout 1s
    }
}
""")
        self.proxy = self.run_container("proxy", "-p", "127.0.0.1::8443", "-v",
            str(self.config) + ":/etc/caddy/Caddyfile:ro", CADDY_IMAGE)
        self.proxy_port = self.port(self.proxy, 8443)
        root_certificate = eventually(lambda: command("docker", "exec", self.proxy, "cat",
            "/data/caddy/pki/authorities/local/root.crt"), timeout=30)
        ca_path = self.evidence / "root.crt"
        ca_path.write_text(root_certificate + "\n")
        self.context = ssl.create_default_context(cafile=str(ca_path))
        require(self.context.check_hostname and self.context.verify_mode == ssl.CERT_REQUIRED, "TLS verification disabled")
        eventually(lambda: self.api("/api/health")["status"] == "ok")
        with socket.create_connection(("127.0.0.1", self.proxy_port), timeout=5) as plain:
            with self.context.wrap_socket(plain, server_hostname="localhost") as secure:
                self.result["tls"] = {"version": secure.version(), "cipher": secure.cipher(), "hostname": "localhost",
                    "certificate_sha256": hashlib.sha256(secure.getpeercert(binary_form=True)).hexdigest(),
                    "public_root_sha256": hashlib.sha256(ca_path.read_bytes()).hexdigest()}
        for label, context, hostname in (("untrusted_root_rejected", ssl.create_default_context(), "localhost"),
                                         ("wrong_hostname_rejected", self.context, "invalid.example")):
            try:
                with socket.create_connection(("127.0.0.1", self.proxy_port), timeout=5) as plain:
                    with context.wrap_socket(plain, server_hostname=hostname):
                        raise AssertionError(f"{label}: invalid TLS peer accepted")
            except ssl.SSLError:
                self.result["checks"][label] = True
        self.result["checks"]["trusted_ca_and_hostname_verified"] = True

    def api(self, path, expected=200, **kwargs):
        return accepted(self.proxy_port, path, expected=expected, context=self.context, **kwargs)

    def metrics(self):
        return {replica: accepted(port, "/api/metrics") for replica, port in self.ports.items()}

    def idle(self):
        metrics = self.metrics()
        return all(value["activeStreams"] == 0 and value["activeRequests"] <= 1 for value in metrics.values())

    def orders(self, label):
        key = self.prefix + "-" + label
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
            repeated = list(executor.map(lambda _: self.api("/api/orders", expected=201, method="POST", body=ORDER,
                headers={"Idempotency-Key": key}), range(16)))
            distinct = list(executor.map(lambda _: self.api("/api/orders", expected=201, method="POST", body=ORDER), range(16)))
        ids = {value["id"] for value in repeated}
        require(len(ids) == 1 and all(value["totalCents"] == 5098 for value in repeated), "concurrent idempotent order mismatch")
        require(len({value["id"] for value in distinct}) == 16, "concurrent independent order IDs collided")
        require(all(value["totalCents"] == 5098 for value in distinct), "order total mismatch")
        changed = {**ORDER, "customerEmail": "changed@example.com"}
        status, _ = exchange(self.proxy_port, "/api/orders", method="POST", body=changed,
                             headers={"Idempotency-Key": key}, context=self.context)
        require(status == 409, f"idempotency conflict returned {status}")
        order = repeated[0]
        require(self.api(f"/api/orders/{order['id']}") == order, "saved order differs from created order")
        self.result["checks"][label + "_orders"] = {"replays": 16, "distinct_orders": 16, "idempotent_order_id": order["id"]}
        return order

    def preflight(self):
        self.set_phase("preflight")
        instances = {self.api("/api/health")["instance"] for _ in range(16)}
        require(instances == {"a", "b"}, f"proxy did not reach two replicas: {instances}")
        require(len(self.api("/api/products")["products"]) >= 3, "seed products missing")
        self.order = self.orders("before_faults")
        connection = http.client.HTTPSConnection("localhost", self.proxy_port, context=self.context, timeout=6)
        mark = time.monotonic()
        with connection_budget(connection, 6) as (transport, deadline):
            connection.request("GET", "/api/events?count=3&delay_ms=150")
            response = connection.getresponse()
            lines = response_lines(response, transport, deadline)
            first_event(response, lines)
            arrivals = [time.monotonic() - mark]
            for line in lines:
                if line.startswith(b"data:"):
                    arrivals.append(time.monotonic() - mark)
        require(len(arrivals) == 3 and arrivals[-1] - arrivals[0] >= .2 and arrivals[0] < 2,
                f"SSE did not arrive incrementally: {arrivals}")
        self.result["checks"]["incremental_sse_seconds"] = arrivals
        cancelled_before = sum(value["cancelled"] for value in self.metrics().values())
        connection = http.client.HTTPSConnection("localhost", self.proxy_port, context=self.context, timeout=6)
        with connection_budget(connection, 6) as (transport, deadline):
            connection.request("GET", "/api/events?count=10000&delay_ms=100")
            response = connection.getresponse()
            first_event(response, response_lines(response, transport, deadline))
            response.close()
        eventually(lambda: self.idle() and sum(value["cancelled"] for value in self.metrics().values()) > cancelled_before)
        self.result["checks"]["disconnect_releases_stream"] = True
        for _ in range(40):
            self.api("/api/products")
        self.set_phase("baseline")
        eventually(self.idle)
        for _ in range(BUDGETS["window_samples"]):
            self.sample()
            time.sleep(1)

    def sample(self):
        for replica in ("a", "b"):
            with self.lock:
                phase, generation, expected_missing = self.phase, self.generations[replica], replica in self.restarting
                port = self.ports[replica]
            record = {"timestamp": timestamp(), "elapsed_seconds": time.monotonic() - self.started,
                      "phase": phase, "instance": replica, "generation": generation}
            try:
                state = json.loads(command("docker", "inspect", "--format", "{{json .State}}", self.prefix + "-" + replica))
                require(state["Running"], f"replica {replica} unexpectedly stopped")
                record["container_host_pid"] = state["Pid"]
                record["process_started_at"] = state["StartedAt"]
                values = command("docker", "exec", self.prefix + "-" + replica, "sh", "-c", """
awk '/^VmRSS:/ {print "rss_kib=" $2} /^Threads:/ {print "threads=" $2}' /proc/1/status
printf 'fd_count='; find /proc/1/fd -mindepth 1 -maxdepth 1 | wc -l
awk 'FNR > 1 {total++; if ($4 == "01") established++} END {print "tcp_entries=" total+0; print "tcp_established=" established+0}' /proc/net/tcp /proc/net/tcp6
""")
                record.update({name: int(value) for name, value in (line.split("=", 1) for line in values.splitlines())})
                record["metrics"] = accepted(port, "/api/metrics", timeout=5)
            except Exception as error:
                # Only a deliberately replaced process may have a missing sample.
                # Recheck the flag because replacement may have started mid-sample.
                with self.lock:
                    planned = expected_missing or replica in self.restarting or self.generations[replica] != generation
                record["sample_error"] = str(error)
                record["planned_restart_gap"] = planned
                if not planned:
                    self.sample_errors.append(record)
            if "sample_error" not in record and record["rss_kib"] > BUDGETS["rss_absolute_kib"]:
                record["budget_error"] = "absolute RSS budget exceeded"
                self.sample_errors.append(record)
            with self.lock:
                record["planned_restart_in_progress"] = expected_missing or replica in self.restarting or self.generations[replica] != generation
                self.samples.append(record)
                with (self.evidence / "resources.jsonl").open("a") as log:
                    log.write(json.dumps(record) + "\n")

    def expected_unavailable(self, start, end, path):
        if path not in ("/api/products", f"/api/orders/{self.order['id']}"):
            return False
        with self.lock:
            return any(start <= (window["end"] or end) and end >= window["start"] for window in self.db_windows)

    def worker(self, number, deadline):
        count = 0
        while time.monotonic() < deadline and not self.stop.is_set():
            path = ("/api/health", "/api/products", f"/api/orders/{self.order['id']}",
                    "/api/events?count=3&delay_ms=20")[(count + number) % 4]
            mark = time.monotonic()
            record = {"worker": number, "path": path, "timestamp": timestamp()}
            try:
                status, body = exchange(self.proxy_port, path, context=self.context)
                ended = time.monotonic()
                record["status"] = status
                record["seconds"] = ended - mark
                if status == 503 and self.expected_unavailable(mark, ended, path):
                    record["outcome"] = "expected_database_unavailable"
                else:
                    require(status == 200, f"unexpected HTTP {status}: {body[:200]!r}")
                    if path.startswith("/api/events"):
                        require(body.count(b"data:") == 3, "incomplete load SSE")
                    else:
                        data = json.loads(body)
                        if path == "/api/health":
                            require(data["status"] == "ok", "health response mismatch")
                        elif path == "/api/products":
                            require(len(data["products"]) >= 3, "products response mismatch")
                        else:
                            require(data == self.order, "persistent order changed during load")
                    record["outcome"] = "succeeded"
            except Exception as error:
                record["outcome"] = "unexpected_failure"
                record["error"] = str(error)
                record["seconds"] = time.monotonic() - mark
            with self.lock:
                self.load_records.append(record)
                with (self.evidence / "traffic.jsonl").open("a") as log:
                    log.write(json.dumps(record) + "\n")
            count += 1
            time.sleep(.05)

    def database_fault(self):
        self.set_phase("database-outage")
        with self.lock:
            window = {"start": time.monotonic(), "end": None, "started_at": timestamp()}
            self.db_windows.append(window)
        command("docker", "stop", "-t", "3", self.database)
        observations = {}
        for replica, port in self.ports.items():
            require(accepted(port, "/api/health")["status"] == "ok", "liveness depends on unavailable database")
            eventually(lambda p=port: exchange(p, "/api/ready")[0] == 503)
            eventually(lambda p=port: exchange(p, "/api/products")[0] == 503)
            observations[replica] = {"health": 200, "ready": 503, "business": 503}
        time.sleep(2)
        self.set_phase("database-recovery")
        command("docker", "start", self.database)
        eventually(lambda: command("docker", "exec", self.database, "pg_isready", "-U", "commerce", "-d", "commerce"), timeout=30)
        for port in self.ports.values():
            eventually(lambda p=port: accepted(p, "/api/ready")["status"] == "ready", timeout=30)
        require(self.api(f"/api/orders/{self.order['id']}") == self.order, "order lost across database restart")
        with self.lock:
            window["end"] = time.monotonic()
            window["ended_at"] = timestamp()
        self.result["checks"]["database_fault"] = {"observations": observations, "seconds": window["end"] - window["start"],
                                                      "order_persisted": True}
        self.set_phase("steady-load")

    def rolling_restart(self):
        self.set_phase("rolling-restart")
        # A direct stream deterministically pins the draining replica. All paced
        # worker requests and health failover probes continue through TLS/Caddy.
        connection = http.client.HTTPConnection("127.0.0.1", self.ports["a"], timeout=6)
        with connection_budget(connection, 8) as (transport, deadline):
            connection.request("GET", "/api/events?count=10000&delay_ms=100")
            response = connection.getresponse()
            lines = response_lines(response, transport, deadline)
            require(first_event(response, lines).startswith("data: a:"), "long stream is not on replica a")
            with self.lock:
                self.restarting.add("a")
            mark = time.monotonic()
            command("docker", "kill", "--signal", "TERM", self.prefix + "-a")

            def wait_for_exit():
                code = command("docker", "wait", self.prefix + "-a", timeout=8)
                return code, time.monotonic() - mark

            def wait_for_stream():
                try:
                    for _ in lines:
                        require(time.monotonic() - mark < 6, "long SSE exceeded graceful deadline")
                except (http.client.IncompleteRead, ConnectionResetError):
                    pass  # Expected only for this explicitly terminated long stream.
                return time.monotonic() - mark

            with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
                exited = executor.submit(wait_for_exit)
                stream_ended = executor.submit(wait_for_stream)
                probes = executor.submit(lambda: [self.api("/api/health")["instance"] for _ in range(16)])
                code, elapsed = exited.result()
                stream_elapsed = stream_ended.result()
                observations = probes.result()
            require(code == "0", "graceful exit was nonzero")
            require("b" in observations, "proxy did not fail over to b")
            require(1.5 <= elapsed < 6, f"two-second graceful process drain took {elapsed}s")
            require(1.5 <= stream_elapsed < 6, f"two-second graceful SSE drain took {stream_elapsed}s")
        old_log = command("docker", "logs", self.prefix + "-a")
        require(old_log.count("LIFECYCLE instance=a shutdown") == 1, "shutdown hook count")
        require(old_log.count("LIFECYCLE instance=a cleanup") == 1, "cleanup hook count")
        (self.evidence / "a-before-restart.log").write_text(old_log.replace(self.password, "[redacted]"))
        command("docker", "start", self.prefix + "-a")
        port = self.port(self.prefix + "-a")
        with self.lock:
            self.ports["a"] = port
            self.generations["a"] += 1
        eventually(lambda: accepted(port, "/api/ready")["instance"] == "a", timeout=30)
        require(accepted(port, f"/api/orders/{self.order['id']}") == self.order, "order lost across application restart")
        eventually(lambda: {self.api("/api/health")["instance"] for _ in range(8)} == {"a", "b"})
        with self.lock:
            self.restarting.remove("a")
        self.result["checks"]["rolling_restart"] = {"drain_seconds": elapsed, "stream_drain_seconds": stream_elapsed, "exit_code": 0,
            "proxy_instances_during_drain": observations, "order_persisted": True}
        self.set_phase("steady-load")

    def sustained(self):
        self.set_phase("steady-load")
        start = time.monotonic()
        deadline = start + self.options.duration
        database_done = restart_done = False
        stop_sampling = threading.Event()

        def sample_loop():
            try:
                while not stop_sampling.is_set():
                    mark = time.monotonic()
                    self.sample()
                    stop_sampling.wait(max(0, self.result["sample_interval_seconds"] - (time.monotonic() - mark)))
            except BaseException as error:
                self.sample_errors.append({"timestamp": timestamp(), "sample_error": type(error).__name__ + ": " + str(error),
                                           "source": "sampler thread"})

        sampler = threading.Thread(target=sample_loop, name="resource-sampler")
        sampler.start()
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
            futures = [executor.submit(self.worker, number, deadline) for number in range(4)]
            try:
                while time.monotonic() < deadline:
                    now = time.monotonic()
                    if not database_done and now - start >= self.options.duration * .25:
                        self.database_fault()
                        database_done = True
                    if not restart_done and now - start >= self.options.duration * .6:
                        self.rolling_restart()
                        restart_done = True
                    time.sleep(.1)
            except BaseException:
                self.stop.set()
                raise
            finally:
                stop_sampling.set()
                sampler.join()
                for future in futures:
                    future.result()
        elapsed = time.monotonic() - start
        require(database_done and restart_done, "fault schedule was not completed during sustained traffic")
        successful = [row for row in self.load_records if row["outcome"] == "succeeded"]
        expected = [row for row in self.load_records if row["outcome"] == "expected_database_unavailable"]
        failures = [row for row in self.load_records if row["outcome"] == "unexpected_failure"]
        latencies = sorted(row["seconds"] for row in successful)
        self.result["sustained"] = {"seconds": elapsed, "workers": 4, "pace_seconds": .05,
            "requests_succeeded": len(successful), "expected_database_503": len(expected),
            "unexpected_failures": failures, "p50_ms": statistics.median(latencies) * 1000 if latencies else None,
            "p95_ms": latencies[min(len(latencies) - 1, int(len(latencies) * .95))] * 1000 if latencies else None}
        self.result["database_fault_windows"] = self.db_windows
        require(elapsed >= self.options.duration, "traffic run shorter than requested")
        require(successful and expected, "traffic did not exercise both successful requests and database outage")
        require(not failures, f"unexpected traffic failures: {failures[:5]}")
        require(not self.sample_errors, f"unexpected resource sampling errors: {self.sample_errors[:3]}")
        self.orders("after_faults")
        self.set_phase("idle-final")
        eventually(self.idle)
        for _ in range(BUDGETS["window_samples"]):
            self.sample()
            time.sleep(1)
        self.result["metrics_after"] = self.metrics()
        require(self.idle(), "requests or streams remained active after the trial")
        self.summarize_resources()

    def summarize_resources(self):
        require(not self.sample_errors, f"unexpected resource sampling errors: {self.sample_errors[:3]}")
        good = [row for row in self.samples if "sample_error" not in row and not row.get("planned_restart_in_progress")]
        summaries = []
        for replica in ("a", "b"):
            baseline = [row for row in good if row["instance"] == replica and row["phase"] == "baseline"]
            final = [row for row in good if row["instance"] == replica and row["phase"] == "idle-final"]
            require(len(baseline) == BUDGETS["window_samples"] and len(final) == BUDGETS["window_samples"], "missing idle windows")
            during_load = [row for row in self.samples if row["instance"] == replica and row["phase"] not in ("baseline", "idle-final")]
            minimum = max(2, self.options.duration // self.result["sample_interval_seconds"] - 2)
            require(len(during_load) >= minimum, f"{replica}: resource series has {len(during_load)} samples, expected at least {minimum}")
            fd_growth = statistics.median(row["fd_count"] for row in final) - statistics.median(row["fd_count"] for row in baseline)
            require(fd_growth <= BUDGETS["idle_fd_growth"], f"{replica}: idle FD growth {fd_growth} exceeds budget")
            for generation in sorted({row["generation"] for row in good if row["instance"] == replica}):
                rows = [row for row in good if row["instance"] == replica and row["generation"] == generation]
                width = min(BUDGETS["window_samples"], len(rows))
                first = statistics.median(row["rss_kib"] for row in rows[:width])
                last = statistics.median(row["rss_kib"] for row in rows[-width:])
                growth = last - first
                first_fd = statistics.median(row["fd_count"] for row in rows[:width])
                last_fd = statistics.median(row["fd_count"] for row in rows[-width:])
                require(growth <= BUDGETS["rss_window_growth_kib"], f"{replica} generation {generation}: RSS growth {growth} KiB")
                require(last_fd - first_fd <= BUDGETS["idle_fd_growth"],
                        f"{replica} generation {generation}: FD growth {last_fd - first_fd} exceeds budget")
                summaries.append({"instance": replica, "generation": generation, "samples": len(rows),
                    "window_samples": width, "first_window_rss_median_kib": first, "last_window_rss_median_kib": last,
                    "rss_growth_kib": growth, "peak_rss_kib": max(row["rss_kib"] for row in rows),
                    "peak_fd_count": max(row["fd_count"] for row in rows),
                    "first_window_fd_median": first_fd, "last_window_fd_median": last_fd,
                    "fd_growth_within_generation": last_fd - first_fd,
                    "peak_tcp_established": max(row["tcp_established"] for row in rows),
                    "peak_threads": max(row["threads"] for row in rows), "idle_fd_growth_across_trial": fd_growth})
        self.result["resource_summary"] = {"process_generations": summaries, "samples": len(self.samples),
            "planned_restart_gaps": [row for row in self.samples if row.get("planned_restart_gap")],
            "unexpected_sampling_errors": self.sample_errors}

    def cleanup(self):
        errors = []
        for name in reversed(self.containers):
            try:
                found = subprocess.run(["docker", "inspect", name], capture_output=True, text=True, timeout=15)
            except Exception as error:
                errors.append({"resource": name, "action": "inspect", "error": str(error)})
                found = None
            if found is not None and found.returncode:
                if "No such object" not in found.stderr:
                    errors.append({"resource": name, "action": "inspect", "error": found.stderr[-500:]})
                continue  # A failed docker run may have never created the registered name.
            try:
                command("docker", "stop", "-t", "8", name, timeout=15)
                exit_code = command("docker", "inspect", "--format", "{{.State.ExitCode}}", name)
                require(exit_code == "0", f"container shutdown exited {exit_code}")
            except Exception as error:
                errors.append({"resource": name, "action": "stop", "error": str(error)})
            try:
                outcome = subprocess.run(["docker", "logs", name], capture_output=True, text=True, timeout=15)
                log = (outcome.stdout + outcome.stderr).replace(self.password, "[redacted]")
                (self.evidence / (name.removeprefix(self.prefix + "-") + ".log")).write_text(log)
                if outcome.returncode:
                    errors.append({"resource": name, "action": "logs", "error": "log collection failed"})
                if "Cannot schedule tasks on an EventLoop" in log:
                    errors.append({"resource": name, "action": "log review", "error": "work scheduled on stopped event loop"})
            except Exception as error:
                errors.append({"resource": name, "action": "logs", "error": str(error)})
            try:
                command("docker", "rm", "-fv", name)
            except Exception as error:
                errors.append({"resource": name, "action": "remove", "error": str(error)})
        resources = []
        if self.network_created:
            resources.append(("network", self.prefix))
        if self.volume_created:
            resources.append(("volume", self.prefix + "-data"))
        if not self.options.skip_build and subprocess.run(["docker", "image", "inspect", self.image], capture_output=True).returncode == 0:
            resources.append(("image", self.image))
        for kind, name in resources:
            try:
                command("docker", kind, "rm", name)
            except Exception as error:
                errors.append({"resource": name, "action": "remove " + kind, "error": str(error)})
        self.result["cleanup_errors"] = errors
        if errors:
            self.result["result"] = "failed"
        return errors

    def run(self):
        self.progress.start()
        try:
            self.prepare()
            self.preflight()
            self.sustained()
            self.result["result"] = "passed"
        except BaseException as error:
            self.result["result"] = "failed"
            self.result["error"] = (type(error).__name__ + ": " + str(error)).replace(self.password, "[redacted]")
        finally:
            self.stop.set()
            self.progress.join(timeout=2)
            try:
                self.cleanup()
            except BaseException as error:
                self.result["result"] = "failed"
                self.result.setdefault("cleanup_errors", []).append({"error": str(error).replace(self.password, "[redacted]")})
            self.result["total_seconds"] = time.monotonic() - self.started
            self.result["resource_sampling_errors"] = self.sample_errors
            (self.evidence / "results.json").write_text(json.dumps(self.result, indent=2) + "\n")
            print(json.dumps({"result": self.result["result"], "error": self.result.get("error"),
                              "artifacts": str(self.evidence)}, indent=2), flush=True)
        return 0 if self.result["result"] == "passed" else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--duration", type=int, default=3600, help="sustained traffic seconds, 60...86400 (default 3600)")
    parser.add_argument("--artifacts", required=True, type=pathlib.Path, help="new or empty evidence directory")
    parser.add_argument("--skip-build", help="use an existing image; source binding is verified only when matching build labels exist")
    options = parser.parse_args()
    if not 60 <= options.duration <= 86400:
        parser.error("duration must be between 60 and 86400 seconds")
    if options.artifacts.exists() and (not options.artifacts.is_dir() or any(options.artifacts.iterdir())):
        parser.error("artifacts directory must be new or empty")
    options.artifacts.mkdir(parents=True, exist_ok=True)
    return Trial(options).run()


if __name__ == "__main__":
    raise SystemExit(main())
