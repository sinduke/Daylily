#!/usr/bin/env python3
"""Real loopback HTTP regressions for the deployment harness; standard library only."""
import contextlib
import http.client
import importlib.util
import os
import pathlib
import socket
import threading
import time
import unittest

HARNESS = pathlib.Path(os.environ.get("DAYLILY_TRIAL_HARNESS", pathlib.Path(__file__).with_name("sustained-deployment-trial.py")))
SPEC = importlib.util.spec_from_file_location("sustained_trial", HARNESS)
trial = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(trial)


@contextlib.contextmanager
def peer_server(reply):
    """One explicitly bounded HTTP peer; join its thread and close every socket."""
    listener = socket.socket()
    listener.bind(("127.0.0.1", 0))
    listener.listen(1)
    listener.settimeout(2)
    port = listener.getsockname()[1]
    stop = threading.Event()
    errors = []

    def serve():
        try:
            peer, _ = listener.accept()
            with peer:
                peer.settimeout(2)
                request = b""
                while b"\r\n\r\n" not in request:
                    data = peer.recv(4096)
                    if not data:
                        return
                    request += data
                reply(peer, stop)
        except (BrokenPipeError, ConnectionResetError):
            pass  # Deadline/size-limit cases deliberately close their peer.
        except BaseException as error:
            errors.append(error)

    thread = threading.Thread(target=serve, name="sustained-http-fixture")
    thread.start()
    try:
        yield port
    finally:
        stop.set()
        thread.join(timeout=3)
        listener.close()
        if thread.is_alive():
            raise AssertionError("HTTP fixture thread did not terminate")
        if errors:
            raise AssertionError(f"HTTP fixture failed: {errors!r}")


def fixed_reply(body=b'{"status":"ready"}', length=None):
    size = len(body) if length is None else length

    def reply(peer, stop):
        peer.sendall(f"HTTP/1.1 200 OK\r\nContent-Length: {size}\r\nConnection: close\r\n\r\n".encode() + body)
    return reply


def chunked_reply(chunks, terminate=True, delay=0):
    def reply(peer, stop):
        peer.sendall(b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nContent-Type: text/event-stream\r\nConnection: close\r\n\r\n")
        for chunk in chunks:
            if stop.is_set():
                return
            peer.sendall(f"{len(chunk):x}\r\n".encode() + chunk + b"\r\n")
            if delay:
                stop.wait(delay)
        if terminate:
            peer.sendall(b"0\r\n\r\n")
    return reply


class SustainedHTTPTests(unittest.TestCase):
    def test_content_length_completion(self):
        # Python 3.12 read1 closes the response stream after the final fixed-length
        # bytes. The next loop must not set a timeout on that now-closed socket.
        with peer_server(fixed_reply()) as port:
            self.assertEqual(trial.accepted(port, "/api/ready"), {"status": "ready"})

    def test_empty_content_length(self):
        with peer_server(fixed_reply(b"")) as port:
            self.assertEqual(trial.exchange(port, "/empty"), (200, b""))

    def test_multiple_content_length_reads(self):
        body = b"x" * 20_000
        with peer_server(fixed_reply(body)) as port:
            self.assertEqual(trial.exchange(port, "/large"), (200, body))

    def test_chunked_completion(self):
        with peer_server(chunked_reply([b"first", b"second"])) as port:
            self.assertEqual(trial.exchange(port, "/chunks"), (200, b"firstsecond"))

    def test_eof_delimited_completion(self):
        def reply(peer, stop):
            peer.sendall(b"HTTP/1.1 200 OK\r\nConnection: close\r\n\r\neof body")
        with peer_server(reply) as port:
            self.assertEqual(trial.exchange(port, "/eof"), (200, b"eof body"))

    def test_incomplete_content_length_is_rejected(self):
        with peer_server(fixed_reply(b"partial", length=20)) as port:
            with self.assertRaises((AssertionError, http.client.IncompleteRead)):
                trial.exchange(port, "/truncated")

    def test_incomplete_chunked_body_is_rejected(self):
        with peer_server(chunked_reply([b"partial"], terminate=False)) as port:
            with self.assertRaises(http.client.IncompleteRead):
                trial.exchange(port, "/truncated")

    def test_incremental_sse(self):
        chunks = [b"data: first\n\n", b"data: second\n\n", b"data: third\n\n"]
        received_first = threading.Event()

        def gated_chunks():
            yield chunks[0]
            if not received_first.wait(2):
                raise AssertionError("client waited for the complete body before consuming its first event")
            yield from chunks[1:]

        with peer_server(chunked_reply(gated_chunks())) as port:
            connection = http.client.HTTPConnection("127.0.0.1", port, timeout=1)
            with trial.connection_budget(connection, 3) as (transport, deadline):
                connection.request("GET", "/events")
                response = connection.getresponse()
                lines = trial.response_lines(response, transport, deadline)
                self.assertEqual(trial.first_event(response, lines), "data: first")
                received_first.set()
                data = [line for line in lines if line.startswith(b"data:")]
                self.assertEqual(data, [b"data: second\n", b"data: third\n"])

    def test_continuous_body_obeys_total_deadline(self):
        def reply(peer, stop):
            peer.sendall(b"HTTP/1.1 200 OK\r\nConnection: close\r\n\r\n")
            while not stop.wait(.01):
                peer.sendall(b"x")
        with peer_server(reply) as port:
            mark = time.monotonic()
            with self.assertRaises((TimeoutError, OSError)):
                trial.exchange(port, "/endless", timeout=.15)
            self.assertLess(time.monotonic() - mark, 1)

    def test_trickled_headers_obey_total_deadline(self):
        def reply(peer, stop):
            peer.sendall(b"HTTP/1.1 200 OK\r\nX-Unfinished: ")
            while not stop.wait(.01):
                peer.sendall(b"x")
        with peer_server(reply) as port:
            mark = time.monotonic()
            with self.assertRaises((TimeoutError, OSError, http.client.HTTPException)):
                trial.exchange(port, "/headers", timeout=.15)
            self.assertLess(time.monotonic() - mark, 1)

    def test_oversized_response_is_rejected(self):
        with peer_server(fixed_reply(b"x" * (256 * 1024 + 1))) as port:
            with self.assertRaisesRegex(AssertionError, "exceeded"):
                trial.exchange(port, "/oversize")

    def test_forced_eof_after_sse_events_is_not_success(self):
        def reply(peer, stop):
            peer.sendall(b"HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nConnection: close\r\n\r\ndata: first\n\ndata: second\n\ndata: third\n\n")
            stop.wait(2)
        with peer_server(reply) as port:
            connection = http.client.HTTPConnection("127.0.0.1", port, timeout=1)
            with self.assertRaises((TimeoutError, OSError)):
                with trial.connection_budget(connection, .15) as (transport, deadline):
                    connection.request("GET", "/events")
                    response = connection.getresponse()
                    list(trial.response_lines(response, transport, deadline))

    def test_zero_body_status(self):
        def reply(peer, stop):
            peer.sendall(b"HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n")
        with peer_server(reply) as port:
            self.assertEqual(trial.exchange(port, "/empty"), (204, b""))


if __name__ == "__main__":
    unittest.main(verbosity=2)
