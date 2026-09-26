@_spi(ServiceLifecycle) import DaylilyNIO
import Daylily
import Foundation
import Testing
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

@Suite("Server operation boundaries", .serialized)
struct ServerOperationTests {
    @Test("Duration settings have explicit defaults and preserve nil through the NIO bridge")
    func configuration() {
        let defaults = ServerConfiguration()
        #expect(defaults.requestHeaderTimeout == .seconds(15))
        #expect(defaults.uploadIdleTimeout == .seconds(30))
        #expect(defaults.shutdownGracePeriod == .seconds(10))
        let custom = ServerConfiguration(requestHeaderTimeout: nil, uploadIdleTimeout: nil, shutdownGracePeriod: nil)
        let nio = NIOServerConfiguration(custom)
        #expect(nio.requestHeaderTimeout == nil)
        #expect(nio.uploadIdleTimeout == nil)
        #expect(nio.shutdownGracePeriod == nil)
    }

    @Test("The header deadline covers idle and partial headers", arguments: [false, true])
    func headerDeadline(partial: Bool) async throws {
        let calls = OperationCounter()
        let app = Application { Get("/") { await calls.increment(); return "unexpected" } }
        try await withOperationServer(app, configuration: .init(requestHeaderTimeout: .milliseconds(80))) { server in
            let socket = try OperationSocket(port: server.port)
            defer { socket.close() }
            if partial { try socket.send("GET / HTTP/1.1\r\nHost: local") }
            let wire = try await Task.detached { try socket.readToEnd() }.value
            #expect(wire.isEmpty)
            #expect(await calls.value == 0)
        }
    }

    @Test("Disabling the header deadline permits a delayed complete request")
    func disabledHeaderDeadline() async throws {
        let app = Application { Get("/") { "ok" } }
        try await withOperationServer(app, configuration: .init(requestHeaderTimeout: nil)) { server in
            let socket = try OperationSocket(port: server.port)
            defer { socket.close() }
            try socket.send("GET / HTTP/1.1\r\nHost:")
            try await Task.sleep(for: .milliseconds(160))
            try socket.send(" localhost\r\nConnection: close\r\n\r\n")
            let wire = try await Task.detached { try socket.readToEnd() }.value
            #expect(wire.hasSuffix("\r\n\r\nok"))
        }
    }

    @Test("A stalled upload returns 408 and releases its reader")
    func uploadDeadline() async throws {
        let stopped = OperationCounter()
        let app = Application {
            Post("/upload") { request in
                do {
                    let body = try await request.body.string(upTo: .kilobytes(16))
                    await stopped.increment()
                    return body
                } catch {
                    await stopped.increment()
                    throw error
                }
            }
        }
        try await withOperationServer(app, configuration: .init(uploadIdleTimeout: .milliseconds(80))) { server in
            let socket = try OperationSocket(port: server.port)
            defer { socket.close() }
            try socket.send("POST /upload HTTP/1.1\r\nHost: localhost\r\nContent-Length: 100\r\n\r\npartial")
            let wire = try await Task.detached { try socket.readToEnd() }.value
            #expect(wire.hasPrefix("HTTP/1.1 408"))
            try await operationEventually { await stopped.value == 1 }
        }
    }

    @Test("Completed request deadlines never impose a lifetime limit on SSE")
    func sseSurvivesInboundDeadlines() async throws {
        let app = Application {
            Post("/events") { request in
                _ = try await request.body.collect(upTo: .bytes(2))
                return Response.eventStream { writer in
                    try await writer.write(ServerSentEvent(data: "first"))
                    try await Task.sleep(for: .milliseconds(220))
                    try await writer.write(ServerSentEvent(data: "second"))
                }
            }
        }
        try await withOperationServer(app, configuration: .init(requestHeaderTimeout: .milliseconds(60), uploadIdleTimeout: .milliseconds(60))) { server in
            let socket = try OperationSocket(port: server.port)
            defer { socket.close() }
            try socket.send("POST /events HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\nContent-Length: 2\r\n\r\nok")
            let wire = try await Task.detached { try socket.readToEnd() }.value
            #expect(wire.contains("data: first\n\n"))
            #expect(wire.contains("data: second\n\n"))
            #expect(wire.hasSuffix("0\r\n\r\n"))
        }
    }

    @Test("An early streaming response abandons the upload idle deadline")
    func earlyResponseAbandonsUploadDeadline() async throws {
        let app = Application {
            Post("/events") {
                Response.eventStream { writer in
                    try await writer.write(ServerSentEvent(data: "first"))
                    try await Task.sleep(for: .milliseconds(220))
                    try await writer.write(ServerSentEvent(data: "second"))
                }
            }
        }
        try await withOperationServer(app, configuration: .init(uploadIdleTimeout: .milliseconds(60))) { server in
            let socket = try OperationSocket(port: server.port)
            defer { socket.close() }
            try socket.send("POST /events HTTP/1.1\r\nHost: localhost\r\nContent-Length: 100\r\n\r\n")
            let wire = try await Task.detached { try socket.readToEnd() }.value
            #expect(wire.contains("data: first\n\n"))
            #expect(wire.contains("data: second\n\n"))
            #expect(wire.hasSuffix("0\r\n\r\n"))
        }
    }

    @Test("Upload idle time excludes server body backpressure")
    func uploadBackpressureSuspendsDeadline() async throws {
        let started = AsyncStream<Void>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        defer { started.continuation.finish(); release.continuation.finish() }
        let byteCount = 2 * 1024 * 1024
        let app = Application {
            Post("/upload") { request in
                started.continuation.yield()
                for await _ in release.stream.prefix(1) {}
                return "read=\(try await request.body.collect(upTo: .megabytes(3)).count)"
            }
        }
        try await withOperationServer(app, configuration: .init(uploadIdleTimeout: .milliseconds(80))) { server in
            let socket = try OperationSocket(port: server.port)
            defer { socket.close() }
            let sender = Task.detached {
                try socket.send("POST /upload HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\nContent-Length: \(byteCount)\r\n\r\n" + String(repeating: "x", count: byteCount))
            }
            try await operationTimeout { for await _ in started.stream.prefix(1) {} }
            try await Task.sleep(for: .milliseconds(250))
            release.continuation.yield()
            try await sender.value
            let wire = try await Task.detached { try socket.readToEnd() }.value
            #expect(wire.hasPrefix("HTTP/1.1 200"))
            #expect(wire.hasSuffix("read=\(byteCount)"))
        }
    }

    @Test("Graceful shutdown drains the active response and drops queued pipeline work")
    func drainActiveResponse() async throws {
        let started = AsyncStream<Void>.makeStream()
        let release = AsyncStream<Void>.makeStream()
        let queued = OperationCounter()
        let observer = InMemoryResponseTransferObserver()
        defer { started.continuation.finish(); release.continuation.finish() }
        let app = Application {
            Get("/active") {
                started.continuation.yield()
                for await _ in release.stream.prefix(1) {}
                return "completed"
            }
            Get("/queued") { await queued.increment(); return "unexpected" }
        }
        try await withOperationServer(app, configuration: .init(shutdownGracePeriod: .seconds(2)), observer: observer) { server in
            let socket = try OperationSocket(port: server.port)
            let idle = try OperationSocket(port: server.port)
            defer { socket.close(); idle.close() }
            try socket.send("GET /active HTTP/1.1\r\nHost: localhost\r\n\r\nGET /queued HTTP/1.1\r\nHost: localhost\r\n\r\n")
            try await operationTimeout { for await _ in started.stream.prefix(1) {} }
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<8 { group.addTask { _ = server.shutdown.yield() } }
            }
            let idleWire = try await Task.detached { try idle.readToEnd() }.value
            #expect(idleWire.isEmpty)
            release.continuation.yield()
            let wire = try await Task.detached { try socket.readToEnd() }.value
            #expect(wire.hasSuffix("completed"))
            #expect(wire.components(separatedBy: "HTTP/1.1").count == 2)
            #expect(await queued.value == 0)
            try await operationTimeout { try await server.task.value }
            try await operationEventually { await observer.snapshot().count == 1 }
            #expect(await observer.snapshot().first?.outcome == .completed)
        }
    }

    @Test("The graceful deadline cancels an infinite SSE response")
    func drainDeadlineStopsSSE() async throws {
        let stopped = OperationCounter()
        let observer = InMemoryResponseTransferObserver()
        let app = Application {
            Get("/events") {
                Response.eventStream { writer in
                    do {
                        try await writer.write(ServerSentEvent(data: "ready"))
                        try await Task.sleep(for: .seconds(30))
                    } catch {
                        await stopped.increment()
                        throw error
                    }
                }
            }
        }
        try await withOperationServer(app, configuration: .init(shutdownGracePeriod: .milliseconds(100)), observer: observer) { server in
            let socket = try OperationSocket(port: server.port)
            defer { socket.close() }
            try socket.send("GET /events HTTP/1.1\r\nHost: localhost\r\n\r\n")
            _ = try await Task.detached { try socket.read(until: "data: ready\n\n") }.value
            server.shutdown.yield()
            try await operationTimeout { try await server.task.value }
            _ = try await Task.detached { try socket.readToEnd() }.value
            try await operationEventually { await stopped.value == 1 }
            try await operationEventually { await observer.snapshot().count == 1 }
            #expect(await observer.snapshot().first?.outcome == .cancelled)
        }
    }

    @Test("Force cancellation interrupts an unlimited graceful drain")
    func forceCancellationStopsUnlimitedDrain() async throws {
        let app = Application {
            Get("/events") {
                Response.eventStream { writer in
                    try await writer.write("ready")
                    try await Task.sleep(for: .seconds(30))
                }
            }
        }
        try await withOperationServer(app, configuration: .init(shutdownGracePeriod: nil)) { server in
            let socket = try OperationSocket(port: server.port)
            defer { socket.close() }
            try socket.send("GET /events HTTP/1.1\r\nHost: localhost\r\n\r\n")
            _ = try await Task.detached { try socket.read(until: "ready") }.value
            server.shutdown.yield()
            try await Task.sleep(for: .milliseconds(100))
            server.task.cancel()
            try await operationTimeout { try await server.task.value }
            _ = try await Task.detached { try socket.readToEnd() }.value
        }
    }

    @Test("Transfer telemetry ends after the body and stays distinct from handler logging")
    func transferCompletionFollowsBody() async throws {
        let observer = InMemoryResponseTransferObserver()
        let logs = InMemoryRequestLogSink()
        let release = AsyncStream<Void>.makeStream()
        defer { release.continuation.finish() }
        let app = Application {
            Get("/stream") {
                Response(body: .stream { writer in
                    try await writer.write("first")
                    for await _ in release.stream.prefix(1) {}
                    try await writer.write("second")
                })
            }
        }.middleware(RequestIDMiddleware(generator: { "internal-id" }))
            .middleware(RequestLoggingMiddleware(sink: logs))
        try await withOperationServer(app, observer: observer) { server in
            let socket = try OperationSocket(port: server.port)
            defer { socket.close() }
            try socket.send("GET /stream?private=value HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\nx-request-id: external-id\r\n\r\n")
            _ = try await Task.detached { try socket.read(until: "first") }.value
            #expect(await logs.snapshot().count == 1)
            #expect(await observer.snapshot().isEmpty)
            try await Task.sleep(for: .milliseconds(60))
            release.continuation.yield()
            _ = try await Task.detached { try socket.readToEnd() }.value
            try await operationEventually { await observer.snapshot().count == 1 }
            let event = try #require(await observer.snapshot().first)
            #expect(event.outcome == .completed)
            #expect(event.bytesSent == 11)
            #expect(event.durationNanoseconds >= 60_000_000)
            #expect(event.requestID == "internal-id")
            #expect(event.correlationID == "external-id")
            #expect(event.path == "/stream")
        }
    }

    @Test("Failed and disconnected streams each report one terminal event")
    func transferFailuresAndLateProducers() async throws {
        let observer = InMemoryResponseTransferObserver()
        let release = AsyncStream<Void>.makeStream()
        defer { release.continuation.finish() }
        let lateFinished = OperationCounter()
        let app = Application {
            Get("/failure") {
                Response(body: .stream { writer in
                    try await writer.write("partial")
                    throw OperationTestError.expected
                })
            }
            Get("/late") {
                Response(body: .stream { writer in
                    try await writer.write("ready")
                    // Detached work intentionally ignores the producer task's cancellation.
                    await Task.detached { for await _ in release.stream.prefix(1) {} }.value
                    await lateFinished.increment()
                })
            }
        }
        try await withOperationServer(app, observer: observer) { server in
            let failed = try OperationSocket(port: server.port)
            defer { failed.close() }
            try failed.send("GET /failure HTTP/1.1\r\nHost: localhost\r\n\r\n")
            _ = try await Task.detached { try failed.readToEnd() }.value
            let late = try OperationSocket(port: server.port)
            defer { late.close() }
            try late.send("GET /late HTTP/1.1\r\nHost: localhost\r\n\r\n")
            _ = try await Task.detached { try late.read(until: "ready") }.value
            late.close()
            try await operationEventually { await observer.snapshot().count == 2 }
            #expect(await lateFinished.value == 0)
            release.continuation.yield()
            try await operationEventually { await lateFinished.value == 1 }
            let events = await observer.snapshot()
            #expect(events.count == 2)
            #expect(events.first { $0.path == "/failure" }?.outcome == .failed)
            #expect(events.first { $0.path == "/failure" }?.bytesSent == 7)
            #expect(events.first { $0.path == "/late" }?.outcome == .cancelled)
        }
    }

    @Test("A blocked observer does not delay another request or server shutdown")
    func blockedObserverDoesNotBlockTransport() async throws {
        let release = AsyncStream<Void>.makeStream()
        let observer = BlockingOperationObserver(release: release.stream)
        defer { release.continuation.finish() }
        let app = Application { Get("/") { "ok" } }
        try await withOperationServer(app, observer: observer) { server in
            for _ in 0..<2 {
                let socket = try OperationSocket(port: server.port)
                defer { socket.close() }
                try socket.send("GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
                let wire = try await Task.detached { try socket.readToEnd() }.value
                #expect(wire.hasSuffix("ok"))
            }
            try await operationEventually { await observer.count == 2 }
            server.shutdown.yield()
            try await operationTimeout { try await server.task.value }
        }
    }
}

private actor OperationCounter {
    private(set) var value = 0
    func increment() { value += 1 }
}

private actor BlockingOperationObserver: ResponseTransferObserver {
    let release: AsyncStream<Void>
    private(set) var count = 0
    init(release: AsyncStream<Void>) { self.release = release }
    func record(_ event: ResponseTransferEvent) async {
        count += 1
        for await _ in release.prefix(1) {}
    }
}

enum OperationTestError: Error {
    case expected
    case timeout
    case socket(String, Int32)
    case incompleteResponse(String)
}

struct OperationServer: Sendable {
    let port: Int
    let shutdown: AsyncStream<Void>.Continuation
    let task: Task<Void, any Error>
    let server: NIOHTTPServer
}

func operationTimeout<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask(operation: operation)
        group.addTask { try await Task.sleep(for: .seconds(5)); throw OperationTestError.timeout }
        defer { group.cancelAll() }
        return try await group.next()!
    }
}

func operationEventually(_ condition: @escaping @Sendable () async -> Bool) async throws {
    try await operationTimeout {
        while !(await condition()) { try await Task.sleep(for: .milliseconds(5)) }
    }
}

func withOperationServer(
    _ app: Application,
    configuration: NIOServerConfiguration = .init(),
    observer: (any ResponseTransferObserver)? = nil,
    operation: @escaping @Sendable (OperationServer) async throws -> Void
) async throws {
    let port = try OperationSocket.availablePort()
    var configuration = configuration
    configuration.port = port
    configuration.gracefulShutdownSignals = false
    let ready = AsyncThrowingStream<Void, any Error>.makeStream()
    let shutdown = AsyncStream<Void>.makeStream()
    defer { shutdown.continuation.finish() }
    let server = NIOHTTPServer(configuration: configuration, responseObserver: observer) { await app.respond(to: $0) }
    let task = Task {
        do {
            try await server.run(started: {
                ready.continuation.yield()
                ready.continuation.finish()
            }, shutdownRequests: shutdown.stream)
        } catch {
            ready.continuation.finish(throwing: error)
            throw error
        }
    }
    do {
        try await operationTimeout { for try await _ in ready.stream {} }
        try await operation(OperationServer(port: port, shutdown: shutdown.continuation, task: task, server: server))
        task.cancel()
        try await task.value
    } catch {
        task.cancel()
        _ = try? await task.value
        throw error
    }
}

/// A bounded blocking socket, used off the cooperative executor for response reads.
final class OperationSocket: @unchecked Sendable {
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
            throw OperationTestError.socket("connect", saved)
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
            guard count > 0 else { throw OperationTestError.socket("send", errno) }
            sent += count
        }
    }

    func read(until marker: String) throws -> String {
        var result = ""
        while !result.contains(marker) {
            guard let next = try receive() else { throw OperationTestError.incompleteResponse(result) }
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
        guard count > 0 else { throw OperationTestError.socket("recv", errno) }
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
        guard bound == 0 else { throw OperationTestError.socket("bind", errno) }
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(descriptor, $0, &length) }
        }
        guard named == 0 else { throw OperationTestError.socket("getsockname", errno) }
        return Int(UInt16(bigEndian: address.sin_port))
    }

    private static func makeSocket() throws -> Int32 {
        #if canImport(Darwin)
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        #else
        let descriptor = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
        #endif
        guard descriptor >= 0 else { throw OperationTestError.socket("socket", errno) }
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
