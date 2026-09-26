#!/usr/bin/env python3
"""Real HTTP PostgreSQL acceptance. Owns and removes only uniquely named test resources."""
import argparse
import concurrent.futures
import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import time
import urllib.error
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[1]
ORDER = {"customerEmail": "orders@example.com", "items": [{"productID": 1, "quantity": 2}, {"productID": 3, "quantity": 1}]}


def run(*args, check=True, **kwargs):
    return subprocess.run(args, check=check, text=True, capture_output=True, **kwargs)


def http(base, path, body=None, key=None, timeout=12):
    headers = {"Content-Type": "application/json"}
    if key is not None:
        headers["Idempotency-Key"] = key
    request = urllib.request.Request(base + path, data=None if body is None else json.dumps(body).encode(), headers=headers)
    started = time.monotonic()
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            raw, status = response.read(), response.status
    except urllib.error.HTTPError as error:
        raw, status = error.read(), error.code
    try:
        data = json.loads(raw)
    except ValueError:
        data = raw.decode()
    return status, data, time.monotonic() - started


def wait_ready(base, timeout=90):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            if http(base, "/api/ready", timeout=6)[0] == 200:
                return
        except (OSError, TimeoutError):
            pass
        time.sleep(0.25)
    raise AssertionError(f"readiness did not recover: {base}")


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifacts", required=True, type=Path)
    parser.add_argument("--binary", type=Path, help="Test a prebuilt native executable against Docker PostgreSQL")
    parser.add_argument("--image", default="daylily-persistent-commerce:smoke")
    parser.add_argument("--skip-build", action="store_true")
    args = parser.parse_args()
    args.artifacts.mkdir(parents=True, exist_ok=False)
    artifact = args.artifacts.resolve()
    prefix = "daylily-persist-" + uuid.uuid4().hex[:10]
    database = prefix + "-db"
    network = prefix + "-net"
    summary = {"checks": [], "success": False, "sourceRevision": run("git", "rev-parse", "HEAD", cwd=ROOT).stdout.strip(),
               "sourceDirty": bool(run("git", "status", "--porcelain", cwd=ROOT).stdout),
               "mode": "native-http" if args.binary else "docker-http"}
    instances = {}
    started = time.monotonic()

    def check(name, evidence=None):
        summary["checks"].append({"name": name, "evidence": evidence})
        print(f"PASS {name}", flush=True)

    def sql(query):
        return run("docker", "exec", database, "psql", "-U", "commerce", "-d", "commerce", "-Atc", query).stdout.strip()

    def start_instance(index, overrides=None):
        name = prefix + f"-app{index}"
        environment = {"PGHOST": "127.0.0.1" if args.binary else database, "PGPORT": str(pg_port if args.binary else 5432),
                       "PGUSER": "commerce", "PGPASSWORD": "local-test-only", "PGDATABASE": "commerce", "PGSSLMODE": "disable",
                       "PGPOOL_MAX_CONNECTIONS": "4", "DB_OPERATION_TIMEOUT_MS": "1500", "SHUTDOWN_GRACE_MS": "2000",
                       "HOST": "127.0.0.1" if args.binary else "0.0.0.0", "INSTANCE_ID": f"replica-{index}"}
        environment.update(overrides or {})
        if args.binary:
            port = free_port()
            environment["PORT"] = str(port)
            log = (artifact / f"app{index}.log").open("a")
            process = subprocess.Popen([str(args.binary.resolve())], env={**os.environ, **environment}, stdout=log, stderr=subprocess.STDOUT)
            instances[index] = {"process": process, "log": log, "base": f"http://127.0.0.1:{port}", "name": name}
        else:
            command = ["docker", "run", "-d", "--name", name, "--network", network, "-p", "127.0.0.1::8080"]
            for key, value in environment.items():
                command.extend(["-e", f"{key}={value}"])
            run(*command, args.image)
            port = run("docker", "port", name, "8080/tcp").stdout.strip().rsplit(":", 1)[1]
            instances[index] = {"base": f"http://127.0.0.1:{port}", "name": name}
        return instances[index]["base"]

    def stop_instance(index, expected_exit=0):
        item = instances.pop(index, None)
        if item is None:
            return
        if "process" in item:
            process = item["process"]
            if process.poll() is None:
                process.send_signal(signal.SIGTERM)
            try:
                process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
                raise AssertionError("application failed graceful shutdown")
            finally:
                item["log"].close()
            assert process.returncode == expected_exit, f"application exit: {process.returncode}"
        else:
            run("docker", "stop", "-t", "15", item["name"])
            exit_code = run("docker", "inspect", "-f", "{{.State.ExitCode}}", item["name"]).stdout.strip()
            with (artifact / f"app{index}.log").open("a") as log:
                log.write(run("docker", "logs", item["name"], check=False).stdout)
            run("docker", "rm", "-v", item["name"])
            assert exit_code == str(expected_exit), f"application container exit: {exit_code}"

    try:
        run("docker", "info")
        if not args.binary and not args.skip_build:
            with (artifact / "docker-build.log").open("w") as output:
                subprocess.run(["docker", "build", "-t", args.image, "-f", str(ROOT / "examples/commerce-api/persistent/Dockerfile"), str(ROOT)],
                               check=True, stdout=output, stderr=subprocess.STDOUT)
        run("docker", "network", "create", network)
        # Docker can reassign an ephemeral host port on stop/start. Pin the selected
        # port for native clients so the outage exercise keeps the same DB endpoint.
        pg_port = free_port()
        run("docker", "run", "-d", "--name", database, "--network", network, "-p", f"127.0.0.1:{pg_port}:5432",
            "-e", "POSTGRES_USER=commerce", "-e", "POSTGRES_PASSWORD=local-test-only", "-e", "POSTGRES_DB=commerce", "postgres:17")
        pg_port = int(run("docker", "port", database, "5432/tcp").stdout.strip().rsplit(":", 1)[1])
        for _ in range(240):
            if run("docker", "exec", database, "pg_isready", "-U", "commerce", check=False).returncode == 0:
                break
            time.sleep(0.25)
        else:
            raise AssertionError("PostgreSQL did not start")
        summary["postgresImage"] = json.loads(run("docker", "image", "inspect", "postgres:17").stdout)[0]["Id"]
        bases = [start_instance(0), start_instance(1)]
        for base in bases:
            wait_ready(base)
        check("simultaneous replica startup and migration lock")
        status, products, _ = http(bases[0], "/api/products?category=tea")
        assert status == 200 and [p["id"] for p in products["products"]] == [1, 2]
        status, filtered, _ = http(bases[0], "/api/products?category=tea%27%20OR%201%3D1--")
        assert status == 200 and filtered["products"] == []
        check("product reads and SQL binding")
        status, original, _ = http(bases[0], "/api/orders", ORDER, "initial-order")
        assert status == 201 and original["totalCents"] == 5098
        assert http(bases[1], f"/api/orders/{original['id']}")[1] == original
        check("order commit visible across replicas", {"id": original["id"], "totalCents": original["totalCents"]})
        before = int(sql("SELECT count(*) FROM commerce_orders"))
        for index, (items, expected) in enumerate([([], 400), ([{"productID": 1, "quantity": 0}], 400),
                                ([{"productID": 1, "quantity": 10001}], 400),
                                ([{"productID": 4, "quantity": 1}], 400),
                                ([{"productID": 1, "quantity": 1}, {"productID": 999, "quantity": 1}], 404)]):
            status, _, _ = http(bases[0], "/api/orders", {**ORDER, "items": items}, f"invalid-order-{index}")
            assert status == expected, (items, status)
        assert int(sql("SELECT count(*) FROM commerce_orders")) == before
        assert int(sql("SELECT count(*) FROM commerce_order_keys WHERE key LIKE 'invalid-order-%'")) == 0
        check("invalid orders and transactional rollback")
        with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
            responses = list(pool.map(lambda i: http(bases[i % 2], "/api/orders", ORDER, f"parallel-{i}"), range(48)))
        assert all(r[0] == 201 and r[1]["totalCents"] == 5098 for r in responses)
        ids = [r[1]["id"] for r in responses]
        assert len(set(ids)) == 48
        assert int(sql("SELECT count(*) FROM commerce_orders")) == before + 48
        check("48 concurrent cross-replica writes", {"uniqueIDs": len(set(ids))})
        with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
            responses = list(pool.map(lambda i: http(bases[i % 2], "/api/orders", ORDER, "same-key"), range(32)))
        assert all(r[0] == 201 for r in responses), responses
        assert len({r[1]["id"] for r in responses}) == 1
        assert int(sql("SELECT count(*) FROM commerce_orders")) == before + 49
        assert http(bases[0], "/api/orders", {**ORDER, "customerEmail": "different@example.com"}, "same-key")[0] == 409
        check("32 concurrent idempotent retries and conflicting payload")
        sql("UPDATE commerce_products SET in_stock = false, price_cents = 9999 WHERE id = 1")
        status, replay, _ = http(bases[1], "/api/orders", ORDER, "initial-order")
        assert status == 201 and replay == original
        sql("UPDATE commerce_products SET in_stock = true, price_cents = 1299 WHERE id = 1")
        check("idempotent replay preserves the committed price and availability snapshot")
        for index in range(2):
            stop_instance(index)
            bases[index] = start_instance(index)
            wait_ready(bases[index])
            assert http(bases[index], f"/api/orders/{original['id']}")[1] == original
        check("application restart preserves committed orders")
        run("docker", "pause", database)
        status, _, duration = http(bases[0], "/api/ready")
        assert status == 503 and duration < 5, (status, duration)
        run("docker", "unpause", database)
        wait_ready(bases[0])
        check("database blackhole has a bounded operation deadline", {"seconds": duration})
        run("docker", "stop", "-t", "5", database)
        for base in bases:
            assert http(base, "/api/health")[0] == 200
            status, body, duration = http(base, "/api/ready")
            assert status == 503 and duration < 5 and body == "Database temporarily unavailable"
        assert http(bases[0], "/api/orders", ORDER, "outage-retry")[0] == 503
        run("docker", "start", database)
        for base in bases:
            wait_ready(base)
            assert http(base, f"/api/orders/{original['id']}")[1] == original
        assert http(bases[0], "/api/orders", ORDER, "outage-retry")[0] == 201
        assert int(sql("SELECT count(*) FROM commerce_orders")) == before + 50
        check("database stop-start, liveness, bounded 503 and write recovery")
        status, stream, _ = http(bases[0], "/api/events?count=3&delay_ms=10")
        assert status == 200 and stream.count("event: progress") == 3
        connection = urllib.request.urlopen(bases[0] + "/api/events?count=1000&delay_ms=50", timeout=10)
        connection.readline()
        connection.close()
        for _ in range(100):
            metrics = http(bases[0], "/api/metrics")[1]
            if metrics["activeStreams"] == 0:
                break
            time.sleep(0.05)
        assert metrics["activeStreams"] == 0 and metrics["activeRequests"] <= 1
        check("SSE completion and client disconnect cleanup", metrics)
        summary["rowCount"] = int(sql("SELECT count(*) FROM commerce_orders"))
        summary["keyCount"] = int(sql("SELECT count(*) FROM commerce_order_keys"))
        assert summary["keyCount"] == summary["rowCount"]
        for index in list(instances):
            stop_instance(index)
        assert int(sql("SELECT count(*) FROM pg_stat_activity WHERE application_name = 'daylily-commerce'")) == 0
        for index in range(2):
            log = (artifact / f"app{index}.log").read_text()
            assert "pool_closed" in log and "cleanup" in log
        check("graceful HTTP-before-pool shutdown leaves zero application connections")
        start_instance(2, {"PGDATABASE": "does_not_exist"})
        item = instances[2]
        if "process" in item:
            item["process"].wait(timeout=30)
        else:
            run("docker", "wait", item["name"], timeout=30)
        stop_instance(2, expected_exit=1)
        failed_log = (artifact / "app2.log").read_text()
        assert "cleanup" in failed_log and "pool_closed" in failed_log and "LIFECYCLE failed" in failed_log
        assert int(sql("SELECT count(*) FROM pg_stat_activity WHERE application_name = 'daylily-commerce'")) == 0
        check("startup database failure exits nonzero and joins application resources")
        summary["success"] = True
    except BaseException as error:
        summary["error"] = f"{type(error).__name__}: {error}"
        raise
    finally:
        cleanup_errors = []
        for index in list(instances):
            try:
                stop_instance(index)
            except Exception as error:
                cleanup_errors.append(str(error))
        # Also catch a container created just before startup/port discovery failed.
        if not args.binary:
            for index in range(3):
                run("docker", "rm", "-f", "-v", prefix + f"-app{index}", check=False)
        run("docker", "unpause", database, check=False)
        postgres_logs = run("docker", "logs", database, check=False)
        (artifact / "postgres.log").write_text(postgres_logs.stdout + postgres_logs.stderr)
        run("docker", "rm", "-f", "-v", database, check=False)
        run("docker", "network", "rm", network, check=False)
        summary["durationSeconds"] = time.monotonic() - started
        summary["cleanupErrors"] = cleanup_errors
        (artifact / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps({"success": summary["success"], "checks": len(summary["checks"]), "artifacts": str(artifact)}))


if __name__ == "__main__":
    main()
