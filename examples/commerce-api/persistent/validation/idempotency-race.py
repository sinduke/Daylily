#!/usr/bin/env python3
"""Gate PostgreSQL replies to reproduce the empty-lookup/catalog-change race over HTTP.

Requires a native PersistentCommerce binary and Docker PostgreSQL. The first and
retry requests use separate real application processes. A test-only INSERT trigger
holds the first commit; a TCP proxy then holds the retry's initial lookup response.
"""
import argparse
import concurrent.futures
import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import threading
import time
import urllib.error
import urllib.request
import uuid


def run(*args, **kwargs):
    return subprocess.run(args, check=True, capture_output=True, text=True, **kwargs)


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


class LookupGate:
    def __init__(self, postgres_port):
        self.blocked = threading.Event()
        self.release = threading.Event()
        self.listener = socket.socket()
        self.listener.bind(("127.0.0.1", 0))
        self.listener.listen()
        self.port = self.listener.getsockname()[1]
        self.postgres_port = postgres_port
        self.connections = []
        threading.Thread(target=self.accept, daemon=True).start()

    def accept(self):
        while True:
            try:
                downstream, _ = self.listener.accept()
                upstream = socket.create_connection(("127.0.0.1", self.postgres_port))
            except OSError:
                return
            self.connections.extend([downstream, upstream])
            target = threading.Event()
            threading.Thread(target=self.forward, args=(downstream, upstream, target, True), daemon=True).start()
            threading.Thread(target=self.forward, args=(upstream, downstream, target, False), daemon=True).start()

    def forward(self, source, destination, target, frontend):
        tail = b""
        try:
            while data := source.recv(65536):
                if frontend:
                    tail = (tail + data)[-65536:]
                    if b"SELECT id, request::text, payload::text FROM commerce_orders" in tail:
                        target.set()
                elif target.is_set() and not self.release.is_set():
                    self.blocked.set()
                    if not self.release.wait(8):
                        raise TimeoutError("lookup gate was not released")
                destination.sendall(data)
        except (OSError, TimeoutError):
            pass
        finally:
            for connection in (source, destination):
                try:
                    connection.shutdown(socket.SHUT_RDWR)
                except OSError:
                    pass
                connection.close()

    def close(self):
        self.release.set()
        self.listener.close()
        for connection in self.connections:
            try:
                connection.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            connection.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True, type=Path)
    parser.add_argument("--artifacts", required=True, type=Path)
    args = parser.parse_args()
    args.artifacts.mkdir(parents=True, exist_ok=False)
    name = "daylily-key-race-" + uuid.uuid4().hex[:10]
    pg_port = free_port()
    gate = LookupGate(pg_port)
    applications, logs = [], []
    barrier = None
    result = {"success": False}
    order = {"customerEmail": "orders@example.com", "items": [{"productID": 1, "quantity": 2}]}

    def sql(query):
        return run("docker", "exec", name, "psql", "-U", "commerce", "-d", "commerce", "-Atc", query).stdout.strip()

    def eventually(predicate, seconds=10):
        end = time.monotonic() + seconds
        while time.monotonic() < end:
            if predicate():
                return
            time.sleep(0.03)
        raise AssertionError("transaction barrier did not reach the expected state")

    def request(port, body=None):
        path = "/api/orders" if body else "/api/ready"
        req = urllib.request.Request(f"http://127.0.0.1:{port}" + path,
                                     data=json.dumps(body).encode() if body else None,
                                     headers={"Content-Type": "application/json", "Idempotency-Key": "race-key"})
        try:
            with urllib.request.urlopen(req, timeout=10) as response:
                status, data = response.status, response.read().decode()
        except urllib.error.HTTPError as error:
            status, data = error.code, error.read().decode()
        try:
            data = json.loads(data)
        except ValueError:
            pass
        return status, data

    def ready(port):
        try:
            return request(port)[0] == 200
        except OSError:
            return False

    try:
        run("docker", "run", "-d", "--name", name, "-p", f"127.0.0.1:{pg_port}:5432",
            "-e", "POSTGRES_USER=commerce", "-e", "POSTGRES_PASSWORD=race-test-only", "-e", "POSTGRES_DB=commerce", "postgres:17")
        eventually(lambda: subprocess.run(["docker", "exec", name, "pg_isready", "-U", "commerce"], capture_output=True).returncode == 0)
        ports = [free_port(), free_port()]
        for index, port in enumerate(ports):
            environment = {**os.environ, "PGHOST": "127.0.0.1", "PGPORT": str(pg_port if index == 0 else gate.port),
                           "PGUSER": "commerce", "PGPASSWORD": "race-test-only", "PGDATABASE": "commerce", "PGSSLMODE": "disable",
                           "HOST": "127.0.0.1", "PORT": str(port), "INSTANCE_ID": f"race-{index}",
                           "PGPOOL_MAX_CONNECTIONS": "4", "DB_OPERATION_TIMEOUT_MS": "5000"}
            log = (args.artifacts / f"app-{index}.log").open("w")
            logs.append(log)
            applications.append(subprocess.Popen([str(args.binary.resolve())], env=environment, stdout=log, stderr=subprocess.STDOUT))
            eventually(lambda: ready(port))
        sql("""CREATE FUNCTION hold_order_commit() RETURNS trigger LANGUAGE plpgsql AS $$
            BEGIN IF NEW.idempotency_key = 'race-key' THEN PERFORM pg_advisory_xact_lock(730026002); END IF;
            RETURN NEW; END $$;
            CREATE TRIGGER hold_order_commit AFTER INSERT ON commerce_orders
            FOR EACH ROW EXECUTE FUNCTION hold_order_commit();""")
        barrier = subprocess.Popen(["docker", "exec", "-i", name, "psql", "-U", "commerce", "-d", "commerce", "-Atq", "-v", "ON_ERROR_STOP=1"],
                                   stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1)
        barrier.stdin.write("SELECT pg_advisory_lock(730026002); SELECT 'barrier-held';\n")
        barrier.stdin.flush()
        while barrier.stdout.readline().strip() != "barrier-held":
            assert barrier.poll() is None, "commit barrier failed"
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            first = pool.submit(request, ports[0], order)
            eventually(lambda: sql("SELECT count(*) FROM pg_stat_activity WHERE application_name='daylily-commerce' AND wait_event='advisory'") == "1", seconds=1.5)
            retry = pool.submit(request, ports[1], order)
            # The old implementation reaches the empty SELECT immediately. The fixed
            # implementation blocks on the full-key row before it can do that lookup.
            eventually(lambda: gate.blocked.is_set() or sql("""SELECT count(*) FROM pg_stat_activity
                WHERE application_name='daylily-commerce' AND wait_event_type='Lock'
                AND query LIKE '%INSERT INTO commerce_order_keys%'""") == "1", seconds=1.5)
            result["retryReachedLookupBeforeFirstCommit"] = gate.blocked.is_set()
            if gate.blocked.is_set():
                eventually(lambda: sql("""SELECT count(*) FROM pg_stat_activity WHERE application_name='daylily-commerce'
                    AND state='idle in transaction' AND query LIKE '%SELECT id, request::text, payload::text FROM commerce_orders%'""") == "1", seconds=1)
            barrier.stdin.write("SELECT pg_advisory_unlock(730026002);\n\\q\n")
            barrier.stdin.flush()
            barrier.wait(timeout=5)
            result["first"] = first.result(timeout=5)
            assert result["first"][0] == 201, result["first"]
            assert gate.blocked.wait(3), "retry never reached the lookup"
            eventually(lambda: sql("""SELECT count(*) FROM pg_stat_activity WHERE application_name='daylily-commerce'
                AND state='idle in transaction' AND query LIKE '%SELECT id, request::text, payload::text FROM commerce_orders%'""") == "1")
            sql("UPDATE commerce_products SET in_stock=false, price_cents=9999 WHERE id=1")
            gate.release.set()
            result["concurrentRetry"] = retry.result(timeout=5)
        result["afterCommitReplay"] = request(ports[1], order)
        result["rows"] = int(sql("SELECT count(*) FROM commerce_orders"))
        assert result["concurrentRetry"] == result["first"], result
        assert result["afterCommitReplay"] == result["first"] and result["rows"] == 1, result
        result["success"] = True
    except BaseException as error:
        result["error"] = f"{type(error).__name__}: {error}"
        raise
    finally:
        gate.release.set()
        if barrier and barrier.poll() is None:
            barrier.terminate()
            barrier.wait(timeout=5)
        for application in applications:
            if application.poll() is None:
                application.send_signal(signal.SIGTERM)
            try:
                application.wait(timeout=10)
            except subprocess.TimeoutExpired:
                application.kill()
                application.wait()
        for log in logs:
            log.close()
        gate.close()
        subprocess.run(["docker", "rm", "-f", "-v", name], capture_output=True)
        (args.artifacts / "summary.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result))


if __name__ == "__main__":
    main()
