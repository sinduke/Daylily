@_spi(Transport) import DaylilyCore
import Daylily
import DaylilyTesting
import Foundation
import Testing
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

@Suite("ResponseStreaming", .serialized)
struct ResponseStreamingTests {
    @Test("Cancelling a waiting request body reader releases its continuation", arguments: [false, true])
    func cancelledRequestReader(afterSuspension: Bool) async throws {
        let stream = RequestBody.stream()
        let reader = Task { try await stream.body.collect(upTo: .bytes(16)) }
        if afterSuspension { try await Task.sleep(for: .milliseconds(20)) }
        reader.cancel()
        do {
            _ = try await streamingTimeout { try await reader.value }
            Issue.record("A cancelled reader must throw CancellationError")
        } catch is CancellationError {}
        #expect(await stream.writer.write(ByteChunk([1])) == false)
    }

    @Test("Cancelling a backpressured request body producer releases its continuation", arguments: [false, true])
    func cancelledRequestProducer(afterSuspension: Bool) async throws {
        let stream = RequestBody.stream(bufferLimit: .bytes(1))
        #expect(await stream.writer.write(ByteChunk([1])))
        let producer = Task { await stream.writer.write(ByteChunk([2])) }
        if afterSuspension { try await Task.sleep(for: .milliseconds(20)) }
        producer.cancel()
        #expect(try await streamingTimeout { await producer.value } == false)
    }

    @Test("Explicit transport cancellation ends body reads normally")
    func transportCancellationEndsBody() async throws {
        let stream = RequestBody.stream()
        let reader = Task { try await stream.body.collect(upTo: .bytes(16)) }
        await stream.writer.cancel()
        #expect(try await streamingTimeout { try await reader.value }.isEmpty)
        #expect(await stream.writer.write(ByteChunk([1])) == false)
    }

    @Test("An already cancelled task cannot consume a buffered request")
    func cancelledBufferedBody() async throws {
        let reader = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await RequestBody.bytes([1]).collect(upTo: .bytes(16))
        }
        do {
            _ = try await reader.value
            Issue.record("Buffered reads must respect task cancellation")
        } catch is CancellationError {}
    }

    @Test("Streaming bodies collect with an explicit limit and share one-shot state")
    func boundedOneShotCollection() async throws {
        let response = Response(body: .stream { writer in
            try await writer.write("one")
            try await writer.write("two")
        })
        #expect(response.body.isEmpty)
        #expect(response.responseBody.isStreaming)
        try await response.requireBody("onetwo", upTo: .bytes(6))
        await #expect(throws: ResponseBodyError.alreadyConsumed) {
            _ = try await response.collectBody(upTo: .bytes(6))
        }
        let oversized = ResponseBody.stream { try await $0.write("large") }
        await #expect(throws: ResponseBodyError.tooLarge(limit: .bytes(2))) {
            _ = try await oversized.collect(upTo: .bytes(2))
        }
        let mismatch = ResponseBody.stream(length: 5) { try await $0.write("four") }
        await #expect(throws: ResponseBodyError.lengthMismatch(expected: 5, actual: 4)) {
            _ = try await mismatch.collect(upTo: .bytes(8))
        }
        var replaceable = Response(body: .stream { try await $0.write("old") })
        replaceable.body = Array("replacement".utf8)
        #expect(replaceable.bodyString == "replacement")
        #expect(!replaceable.responseBody.isStreaming)
        let json = Response(body: .stream { try await $0.write("{\"value\":42}") })
        try await json.requireJSON(["value": 42], upTo: .bytes(32))
    }

    @Test("Server-sent events encode multiline data without field injection")
    func eventEncoding() {
        let event = ServerSentEvent(data: "first\r\nsecond\rthird\n", id: "a\nb\0", event: "up\rdate", retry: 1000)
        #expect(event.encoded == "id: ab\nevent: update\nretry: 1000\ndata: first\ndata: second\ndata: third\ndata: \n\n")
    }

    @Test("Writers reject overlapping writes and cannot escape the producer lifetime")
    func writerLifetimeAndConcurrency() async throws {
        let enteredSink = AsyncStream<Void>.makeStream()
        let releaseSink = AsyncStream<Void>.makeStream()
        let captured = StreamingWriterStore()
        defer { enteredSink.continuation.finish(); releaseSink.continuation.finish() }
        let body = ResponseBody.stream { writer in
            await captured.retain(writer)
            async let first: Void = writer.write("one")
            for await _ in enteredSink.stream.prefix(1) {}
            do {
                try await writer.write("two")
                Issue.record("Concurrent writes must fail instead of adding an implicit queue")
            } catch ResponseBodyError.concurrentWrite {}
            releaseSink.continuation.yield()
            try await first
        }
        try await streamingTimeout {
            try await body.write { chunk in
                #expect(chunk.bytes == Array("one".utf8))
                enteredSink.continuation.yield()
                for await _ in releaseSink.stream.prefix(1) {}
            }
        }
        let writer = try #require(await captured.writer)
        await #expect(throws: ResponseBodyError.writerFinished) {
            try await writer.write("too late")
        }

        let escapedStarted = AsyncStream<Void>.makeStream()
        let escapedRelease = AsyncStream<Void>.makeStream()
        defer { escapedStarted.continuation.finish(); escapedRelease.continuation.finish() }
        let escaped = ResponseBody.stream { writer in
            await captured.retainTask(Task { try await writer.write("unfinished") })
            for await _ in escapedStarted.stream.prefix(1) {}
            // Deliberately return without awaiting the retained write.
        }
        await #expect(throws: ResponseBodyError.concurrentWrite) {
            try await streamingTimeout {
                try await escaped.write { _ in
                    escapedStarted.continuation.yield()
                    for await _ in escapedRelease.stream.prefix(1) {}
                }
            }
        }
        escapedRelease.continuation.yield()
        let pendingWrite = try #require(await captured.pendingWrite)
        await #expect(throws: ResponseBodyError.writerFinished) {
            try await streamingTimeout { try await pendingWrite.value }
        }
    }

    @Test("A socket receives the first SSE before the producer finishes")
    func incrementalSocketDelivery() async throws {
        let release = AsyncStream<Void>.makeStream()
        let app = Application {
            Get("/events") {
                Response.eventStream { writer in
                    try await writer.write(ServerSentEvent(data: "first"))
                    for await _ in release.stream { break }
                    try await writer.write(ServerSentEvent(data: "second"))
                }
            }
        }
        try await withStreamingServer(app) { port in
            let socket = try StreamingSocket(port: port)
            defer { socket.close(); release.continuation.finish() }
            try socket.send("GET /events HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
            let first = try await Task.detached { try socket.read(until: "data: first\n\n") }.value
            #expect(first.contains("text/event-stream"))
            #expect(first.lowercased().contains("transfer-encoding: chunked"))
            #expect(!first.contains("data: second"))
            release.continuation.yield()
            let rest = try await Task.detached { try socket.readToEnd() }.value
            #expect(rest.contains("data: second\n\n"))
            #expect(rest.hasSuffix("0\r\n\r\n"))
        }
    }

    @Test("HEAD, 204, and 304 suppress producer execution and preserve framing")
    func suppressedBodyFraming() async throws {
        let invocations = StreamingCounter()
        let app = Application {
            Head("/head") {
                Response(body: .stream(length: 12) { writer in
                    await invocations.increment()
                    try await writer.write("not consumed")
                })
            }
            Head("/head-unknown") {
                Response(body: .stream { _ in await invocations.increment() })
            }
            Head("/head-declared") {
                Response(headers: ["content-length": "99"], body: .stream { _ in await invocations.increment() })
            }
            Head("/head-representation") {
                Response(headers: ["content-length": "99"])
            }
            Get("/empty") {
                Response(status: .noContent, headers: ["content-length": "999"], body: .stream { _ in
                    await invocations.increment()
                })
            }
            Get("/cached") {
                Response(status: Status(304, reasonPhrase: "Not Modified"), headers: ["content-length": "99"], body: .stream { _ in
                    await invocations.increment()
                })
            }
        }
        try await withStreamingServer(app) { port in
            for (method, path) in [("HEAD", "/head"), ("HEAD", "/head-unknown"), ("HEAD", "/head-declared"), ("HEAD", "/head-representation"), ("GET", "/empty"), ("GET", "/cached")] {
                let socket = try StreamingSocket(port: port)
                defer { socket.close() }
                try socket.send("\(method) \(path) HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
                let wire = try await Task.detached { try socket.readToEnd() }.value
                let parts = wire.components(separatedBy: "\r\n\r\n")
                #expect(parts.count == 2)
                #expect(parts.last == "")
                #expect(!wire.lowercased().contains("transfer-encoding:"))
                if path == "/head" { #expect(wire.lowercased().contains("content-length: 12")) }
                if path == "/empty" || path == "/head-unknown" { #expect(!wire.lowercased().contains("content-length:")) }
                if path == "/cached" || path == "/head-declared" || path == "/head-representation" {
                    #expect(wire.lowercased().contains("content-length: 99"))
                }
            }
        }
        #expect(await invocations.value == 0)
    }

    @Test("Producer failures after headers close the socket without a second response")
    func producerFailureClosesSocket() async throws {
        let app = Application {
            Get("/failure") {
                Response(body: .stream { writer in
                    try await writer.write("partial")
                    throw StreamingTestError.expected
                })
            }
        }
        try await withStreamingServer(app) { port in
            let socket = try StreamingSocket(port: port)
            defer { socket.close() }
            try socket.send("GET /failure HTTP/1.1\r\nHost: localhost\r\n\r\n")
            let wire = try await Task.detached { try socket.readToEnd() }.value
            #expect(wire.contains("partial"))
            #expect(wire.components(separatedBy: "HTTP/1.1").count == 2)
            #expect(!wire.hasSuffix("0\r\n\r\n"))
        }
    }

    @Test("Known-length streams use exact framing and reject incomplete producers")
    func knownLengthFraming() async throws {
        let app = Application {
            Get("/known") {
                Response(headers: ["content-length": "999", "transfer-encoding": "chunked"], body: .stream(length: 6) { writer in
                    try await writer.write("abc")
                    try await writer.write("def")
                })
            }
            Get("/short") {
                Response(body: .stream(length: 10) { try await $0.write("short") })
            }
        }
        try await withStreamingServer(app) { port in
            for path in ["/known", "/short"] {
                let socket = try StreamingSocket(port: port)
                defer { socket.close() }
                try socket.send("GET \(path) HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
                let wire = try await Task.detached { try socket.readToEnd() }.value
                #expect(!wire.lowercased().contains("transfer-encoding:"))
                #expect(wire.components(separatedBy: "HTTP/1.1").count == 2)
                if path == "/known" {
                    #expect(wire.lowercased().contains("content-length: 6\r\n"))
                    #expect(wire.hasSuffix("\r\n\r\nabcdef"))
                } else {
                    #expect(wire.lowercased().contains("content-length: 10\r\n"))
                    #expect(wire.hasSuffix("\r\n\r\nshort"))
                }
            }
        }
    }

    @Test("A streamed response releases the next pipelined request only after its end")
    func pipelinedStreamingResponses() async throws {
        let app = Application {
            Get("/first") {
                Response(body: .stream { writer in
                    try await writer.write("first-part")
                    try await writer.write("-done")
                })
            }
            Get("/second") { "second-response" }
        }
        try await withStreamingServer(app) { port in
            let socket = try StreamingSocket(port: port)
            defer { socket.close() }
            try socket.send("GET /first HTTP/1.1\r\nHost: localhost\r\n\r\nGET /second HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
            let wire = try await Task.detached { try socket.readToEnd() }.value
            #expect(wire.components(separatedBy: "HTTP/1.1 200 OK").count == 3)
            #expect(wire.contains("first-part"))
            #expect(wire.contains("-done\r\n0\r\n\r\nHTTP/1.1 200 OK"))
            #expect(wire.hasSuffix("second-response"))
        }
    }

    @Test("An explicit connection close token ends an otherwise persistent response")
    func responseConnectionClose() async throws {
        let app = Application {
            Get("/close") {
                Response.text("closed", headers: Headers(fields: [
                    ("connection", "keep-alive, Close"),
                    ("connection", "extension"),
                ]))
            }
        }
        try await withStreamingServer(app) { port in
            let socket = try StreamingSocket(port: port)
            defer { socket.close() }
            try socket.send("GET /close HTTP/1.1\r\nHost: localhost\r\n\r\n")
            let wire = try await Task.detached { try socket.readToEnd() }.value
            #expect(wire.lowercased().contains("connection: close\r\n"))
            #expect(wire.hasSuffix("\r\n\r\nclosed"))
        }
    }

    @Test("Disconnect cancels a handler that does not consume its request body")
    func disconnectCancelsHandler() async throws {
        let started = AsyncStream<Void>.makeStream()
        let stopped = AsyncStream<Void>.makeStream()
        let app = Application {
            Get("/wait") {
                started.continuation.yield()
                defer { stopped.continuation.yield(); stopped.continuation.finish() }
                try await Task.sleep(for: .seconds(30))
                return "too late"
            }
        }
        try await withStreamingServer(app) { port in
            let socket = try StreamingSocket(port: port)
            defer { socket.close(); started.continuation.finish() }
            try socket.send("GET /wait HTTP/1.1\r\nHost: localhost\r\n\r\n")
            try await streamingTimeout { for await _ in started.stream { break } }
            socket.close()
            try await streamingTimeout { for await _ in stopped.stream { break } }
        }
    }

    @Test("Disconnect releases a handler waiting for the remaining upload")
    func disconnectCancelsBodyReader() async throws {
        let started = AsyncStream<Void>.makeStream()
        let stopped = AsyncStream<Void>.makeStream()
        let app = Application {
            Post("/upload") { request in
                started.continuation.yield()
                defer { stopped.continuation.yield(); stopped.continuation.finish() }
                return try await request.body.string(upTo: .kilobytes(16))
            }
        }
        try await withStreamingServer(app) { port in
            let socket = try StreamingSocket(port: port)
            defer { socket.close(); started.continuation.finish() }
            try socket.send("POST /upload HTTP/1.1\r\nHost: localhost\r\nContent-Length: 100\r\n\r\npartial")
            try await streamingTimeout { for await _ in started.stream { break } }
            socket.close()
            try await streamingTimeout { for await _ in stopped.stream { break } }
        }
    }

    @Test("Disconnect cancels a producer suspended between response chunks")
    func disconnectCancelsSuspendedProducer() async throws {
        let stopped = AsyncStream<Void>.makeStream()
        let app = Application {
            Get("/waiting-stream") {
                Response.eventStream { writer in
                    defer { stopped.continuation.yield(); stopped.continuation.finish() }
                    try await writer.write(ServerSentEvent(data: "ready"))
                    try await Task.sleep(for: .seconds(30))
                    try await writer.write(ServerSentEvent(data: "too late"))
                }
            }
        }
        try await withStreamingServer(app) { port in
            let socket = try StreamingSocket(port: port)
            defer { socket.close() }
            try socket.send("GET /waiting-stream HTTP/1.1\r\nHost: localhost\r\n\r\n")
            _ = try await Task.detached { try socket.read(until: "data: ready\n\n") }.value
            socket.close()
            try await streamingTimeout { for await _ in stopped.stream { break } }
        }
    }

    @Test("Bind collisions fail promptly and leave the existing listener usable")
    func bindFailureReleasesResources() async throws {
        let app = Application { Get("/health") { "ok" } }
        try await withStreamingServer(app) { port in
            for _ in 0..<2 {
                let server = NIOHTTPServer(configuration: .init(port: port, gracefulShutdownSignals: false)) { _ in
                    .text("unexpected")
                }
                do {
                    try await streamingTimeout { try await server.run() }
                    Issue.record("An occupied port must reject binding")
                } catch StreamingTestError.timeout {
                    Issue.record("Bind failure did not return within the deadline")
                } catch {}
            }
            let socket = try StreamingSocket(port: port)
            defer { socket.close() }
            try socket.send("GET /health HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
            let wire = try await Task.detached { try socket.readToEnd() }.value
            #expect(wire.hasSuffix("\r\n\r\nok"))
        }
    }

    @Test("Stopping the server cancels active handlers and response producers")
    func shutdownCancelsInflightWork() async throws {
        let started = AsyncStream<Void>.makeStream()
        let stopped = AsyncStream<Void>.makeStream()
        let sockets = StreamingSocketStore()
        defer { started.continuation.finish(); stopped.continuation.finish() }
        let app = Application {
            Get("/handler") {
                started.continuation.yield()
                defer { stopped.continuation.yield() }
                try await streamingWaitForCancellationWithCleanup()
                return "too late"
            }
            Get("/producer") {
                Response.eventStream { writer in
                    defer { stopped.continuation.yield() }
                    try await writer.write(ServerSentEvent(data: "ready"))
                    started.continuation.yield()
                    try await streamingWaitForCancellationWithCleanup()
                }
            }
        }
        do {
            try await withStreamingServer(app) { port in
                for path in ["/handler", "/producer"] {
                    let socket = try StreamingSocket(port: port)
                    await sockets.retain(socket)
                    try socket.send("GET \(path) HTTP/1.1\r\nHost: localhost\r\n\r\n")
                }
                try await streamingTimeout { for await _ in started.stream.prefix(2) {} }
                // Keep client sockets open while the helper cancels the server.
            }
            try await streamingTimeout { for await _ in stopped.stream.prefix(2) {} }
            await sockets.close()
        } catch {
            await sockets.close()
            throw error
        }
    }

    @Test("A slow socket backpressures response production and disconnect stops it")
    func slowConsumerBackpressureAndDisconnect() async throws {
        let count = StreamingCounter()
        let started = AsyncStream<Void>.makeStream()
        let stopped = AsyncStream<Void>.makeStream()
        let chunk = [UInt8](repeating: 120, count: 64 * 1024)
        let app = Application {
            Get("/large") {
                Response(body: .stream { writer in
                    started.continuation.yield()
                    defer { stopped.continuation.yield(); stopped.continuation.finish() }
                    for _ in 0..<2048 {
                        try await writer.write(chunk)
                        await count.increment()
                    }
                })
            }
        }
        try await withStreamingServer(app) { port in
            let socket = try StreamingSocket(port: port, receiveBuffer: 4096)
            defer { socket.close(); started.continuation.finish() }
            try socket.send("GET /large HTTP/1.1\r\nHost: localhost\r\n\r\n")
            try await streamingTimeout { for await _ in started.stream { break } }
            try await Task.sleep(for: .milliseconds(150))
            #expect(await count.value < 2048)
            socket.close()
            try await streamingTimeout { for await _ in stopped.stream { break } }
            let stoppedCount = await count.value
            try await Task.sleep(for: .milliseconds(20))
            #expect(await count.value == stoppedCount)
        }
    }
}

private actor StreamingCounter {
    private(set) var value = 0
    func increment() { value += 1 }
}

private actor StreamingSocketStore {
    private var sockets: [StreamingSocket] = []
    func retain(_ socket: StreamingSocket) { sockets.append(socket) }
    func close() {
        for socket in sockets { socket.close() }
        sockets.removeAll()
    }
}

private actor StreamingWriterStore {
    private(set) var writer: ResponseBodyWriter?
    private(set) var pendingWrite: Task<Void, any Error>?
    func retain(_ writer: ResponseBodyWriter) { self.writer = writer }
    func retainTask(_ task: Task<Void, any Error>) { pendingWrite = task }
}

private enum StreamingTestError: Error {
    case expected
    case timeout
    case socket(String, Int32)
    case incompleteResponse(String)
}

private func streamingWaitForCancellationWithCleanup() async throws {
    do {
        try await Task.sleep(for: .seconds(30))
    } catch {
        // Simulate bounded user cleanup that outlives the channel and its event loop.
        // A late handler completion or producer failure must not schedule NIO work.
        await Task.detached { try? await Task.sleep(for: .milliseconds(30)) }.value
        throw error
    }
}

private func streamingTimeout<T: Sendable>(
    _ operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask(operation: operation)
        group.addTask {
            try await Task.sleep(for: .seconds(5))
            throw StreamingTestError.timeout
        }
        defer { group.cancelAll() }
        return try await group.next()!
    }
}

private func withStreamingServer(
    _ app: Application,
    operation: @escaping @Sendable (Int) async throws -> Void
) async throws {
    let port = try StreamingSocket.availablePort()
    let ready = AsyncThrowingStream<Void, any Error>.makeStream()
    let server = NIOHTTPServer(configuration: .init(port: port, gracefulShutdownSignals: false)) { request in
        await app.respond(to: request)
    }
    let task = Task {
        do {
            try await server.run {
                ready.continuation.yield()
                ready.continuation.finish()
            }
        } catch {
            ready.continuation.finish(throwing: error)
            throw error
        }
    }
    do {
        try await streamingTimeout { for try await _ in ready.stream {} }
        try await operation(port)
        task.cancel()
        try await task.value
    } catch {
        task.cancel()
        _ = try? await task.value
        throw error
    }
}

/// A bounded blocking socket, used off the cooperative executor for response reads.
private final class StreamingSocket: @unchecked Sendable {
    private let lock = NSLock()
    private var descriptor: Int32

    init(port: Int, receiveBuffer: Int32 = 64 * 1024) throws {
        descriptor = try Self.makeSocket()
        var bufferSize = receiveBuffer
        _ = setsockopt(descriptor, SOL_SOCKET, SO_RCVBUF, &bufferSize, socklen_t(MemoryLayout<Int32>.size))
        var timeout = timeval(tv_sec: 3, tv_usec: 0)
        _ = setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        _ = setsockopt(descriptor, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        var address = Self.address(port: port)
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if result != 0 {
            let saved = errno
            close()
            throw StreamingTestError.socket("connect", saved)
        }
    }

    deinit { close() }

    func close() {
        lock.lock()
        let descriptor = descriptor
        self.descriptor = -1
        lock.unlock()
        if descriptor >= 0 {
            _ = shutdown(descriptor, Int32(SHUT_RDWR))
            Self.closeDescriptor(descriptor)
        }
    }

    func send(_ request: String) throws {
        let bytes = Array(request.utf8)
        var sent = 0
        while sent < bytes.count {
            let count = bytes.withUnsafeBytes { buffer in
                #if canImport(Darwin)
                Darwin.send(descriptor, buffer.baseAddress!.advanced(by: sent), bytes.count - sent, 0)
                #else
                Glibc.send(descriptor, buffer.baseAddress!.advanced(by: sent), bytes.count - sent, Int32(MSG_NOSIGNAL))
                #endif
            }
            guard count > 0 else { throw StreamingTestError.socket("send", errno) }
            sent += count
        }
    }

    func read(until marker: String) throws -> String {
        var result = ""
        while !result.contains(marker) {
            guard let next = try receive() else { throw StreamingTestError.incompleteResponse(result) }
            result += next
        }
        return result
    }

    func readToEnd() throws -> String {
        var result = ""
        while let next = try receive() { result += next }
        return result
    }

    private func receive() throws -> String? {
        var bytes = [UInt8](repeating: 0, count: 8192)
        let count = recv(descriptor, &bytes, bytes.count, 0)
        if count == 0 { return nil }
        guard count > 0 else { throw StreamingTestError.socket("recv", errno) }
        return String(decoding: bytes.prefix(count), as: UTF8.self)
    }

    static func availablePort() throws -> Int {
        let descriptor = try makeSocket()
        defer { closeDescriptor(descriptor) }
        var address = address(port: 0)
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0 else { throw StreamingTestError.socket("bind", errno) }
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(descriptor, $0, &length) }
        }
        guard named == 0 else { throw StreamingTestError.socket("getsockname", errno) }
        return Int(UInt16(bigEndian: address.sin_port))
    }

    private static func makeSocket() throws -> Int32 {
        #if canImport(Darwin)
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        #else
        let descriptor = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
        #endif
        guard descriptor >= 0 else { throw StreamingTestError.socket("socket", errno) }
        #if canImport(Darwin)
        var noSignal: Int32 = 1
        _ = setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout<Int32>.size))
        #endif
        return descriptor
    }

    private static func address(port: Int) -> sockaddr_in {
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = UInt16(port).bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        return address
    }

    private static func closeDescriptor(_ descriptor: Int32) {
        #if canImport(Darwin)
        _ = Darwin.close(descriptor)
        #else
        _ = Glibc.close(descriptor)
        #endif
    }
}
