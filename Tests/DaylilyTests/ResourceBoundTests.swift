@_spi(ServiceLifecycle) import DaylilyNIO
import Daylily
import Testing

@Suite("Runtime resource bounds", .serialized)
struct ResourceBoundTests {
    @Test("Write deadline and observer capacity bridge with source-compatible defaults")
    func configuration() {
        let defaults = ServerConfiguration()
        #expect(defaults.responseWriteTimeout == .seconds(30))
        #expect(defaults.responseObserverCapacity == 64)
        let custom = ServerConfiguration(responseWriteTimeout: nil, responseObserverCapacity: 3)
        let nio = NIOServerConfiguration(custom)
        #expect(nio.responseWriteTimeout == nil)
        #expect(nio.responseObserverCapacity == 3)
        let server = NIOHTTPServer { _ in .text("ok") }
        #expect(server.responseObserverSnapshot == nil)
    }

    @Test("Blocked observers have a server-wide limit and recover without queued events")
    func observationSaturationAndRecovery() async throws {
        let release = AsyncStream<Void>.makeStream()
        defer { release.continuation.finish() }
        let observer = ResourceBlockingObserver(release: release.stream)
        let app = Application { Get("/") { "ok" } }
        try await withOperationServer(app, configuration: .init(responseObserverCapacity: 2), observer: observer) { server in
            // Every request uses a new connection, so the limit must be shared.
            for _ in 0..<40 { try await resourceRequest(port: server.port) }
            try await operationEventually { await observer.started == 2 }
            let saturated = try #require(server.server.responseObserverSnapshot)
            #expect(saturated.capacity == 2)
            #expect(saturated.inFlight == 2)
            #expect(saturated.completedEvents == 0)
            #expect(saturated.droppedEvents == 38)
            let copy = server.server
            #expect(copy.responseObserverSnapshot == saturated)

            release.continuation.finish()
            try await operationEventually { server.server.responseObserverSnapshot?.completedEvents == 2 }
            #expect(server.server.responseObserverSnapshot?.inFlight == 0)
            #expect(await observer.started == 2)
            try await resourceRequest(port: server.port)
            try await operationEventually { server.server.responseObserverSnapshot?.completedEvents == 3 }
            #expect(await observer.started == 3)
            #expect(server.server.responseObserverSnapshot?.droppedEvents == 38)
        }
    }

    @Test("A saturated observer does not delay shutdown and retains only its fixed slots")
    func saturatedObserverShutdown() async throws {
        let release = AsyncStream<Void>.makeStream()
        defer { release.continuation.finish() }
        let observer = ResourceBlockingObserver(release: release.stream)
        let app = Application { Get("/") { "ok" } }
        try await withOperationServer(app, configuration: .init(responseObserverCapacity: 1), observer: observer) { server in
            for _ in 0..<5 { try await resourceRequest(port: server.port) }
            try await operationEventually { await observer.started == 1 }
            server.shutdown.yield()
            try await operationTimeout { try await server.task.value }
            #expect(server.server.responseObserverSnapshot?.inFlight == 1)
            #expect(server.server.responseObserverSnapshot?.droppedEvents == 4)
        }
    }

    @Test("A non-reading peer expires a pending write, cancels its producer and records failure once")
    func stalledWriteDeadline() async throws {
        let observer = InMemoryResponseTransferObserver()
        let progress = ResourceProducerProgress()
        let app = resourceStreamingApp(progress: progress)
        try await withOperationServer(app, configuration: .init(responseWriteTimeout: .milliseconds(100)), observer: observer) { server in
            let socket = try OperationSocket(port: server.port, receiveBuffer: 1024)
            defer { socket.close() }
            try socket.send("GET /large HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
            // Deliberately never read: this eventually fills the TCP write queue.
            try await operationEventually { await progress.stopped }
            try await operationEventually { await observer.snapshot().count == 1 }
            #expect(await progress.cancelled)
            #expect(await progress.chunksWritten < 4096)
            let event = try #require(await observer.snapshot().first)
            #expect(event.outcome == .failed)
            #expect(event.path == "/large")
            #expect(event.bytesSent < 4096 * 65_536)
            try await resourceRequest(port: server.port)
            try await operationEventually { await observer.snapshot().count == 2 }
            #expect(await observer.snapshot().filter { $0.path == "/large" }.count == 1)
        }
    }

    @Test("Disabling the write deadline preserves a blocked producer until disconnect")
    func disabledWriteDeadline() async throws {
        let observer = InMemoryResponseTransferObserver()
        let progress = ResourceProducerProgress()
        let app = resourceStreamingApp(progress: progress)
        try await withOperationServer(app, configuration: .init(responseWriteTimeout: nil), observer: observer) { server in
            let socket = try OperationSocket(port: server.port, receiveBuffer: 1024)
            defer { socket.close() }
            try socket.send("GET /large HTTP/1.1\r\nHost: localhost\r\n\r\n")
            try await operationEventually { await progress.chunksWritten > 0 }
            try await Task.sleep(for: .milliseconds(350))
            #expect(!(await progress.stopped))
            #expect(await observer.snapshot().isEmpty)
            socket.close()
            try await operationEventually { await progress.stopped }
            try await operationEventually { await observer.snapshot().count == 1 }
            #expect(await observer.snapshot().first?.outcome == .cancelled)
        }
    }

    @Test("Handler wait and idle SSE never consume a response write budget")
    func idleProducerSurvivesWriteDeadline() async throws {
        let observer = InMemoryResponseTransferObserver()
        let app = Application {
            Get("/idle") {
                try await Task.sleep(for: .milliseconds(150))
                return Response.eventStream { writer in
                    // No body bytes yet, but the response head already flushed.
                    try await Task.sleep(for: .milliseconds(150))
                    try await writer.write(ServerSentEvent(data: "first"))
                    try await Task.sleep(for: .milliseconds(150))
                    try await writer.write(ServerSentEvent(data: "second"))
                }
            }
        }
        try await withOperationServer(app, configuration: .init(responseWriteTimeout: .milliseconds(50)), observer: observer) { server in
            let socket = try OperationSocket(port: server.port)
            defer { socket.close() }
            try socket.send("GET /idle HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
            let wire = try await Task.detached { try socket.readToEnd() }.value
            #expect(wire.contains("data: first"))
            #expect(wire.contains("data: second"))
            try await operationEventually { await observer.snapshot().count == 1 }
            #expect(await observer.snapshot().first?.outcome == .completed)
        }
    }
}

private func resourceRequest(port: Int) async throws {
    let socket = try OperationSocket(port: port)
    defer { socket.close() }
    try socket.send("GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
    let wire = try await Task.detached { try socket.readToEnd() }.value
    #expect(wire.hasSuffix("ok"))
}

private actor ResourceBlockingObserver: ResponseTransferObserver {
    let release: AsyncStream<Void>
    private(set) var started = 0
    init(release: AsyncStream<Void>) { self.release = release }
    func record(_ event: ResponseTransferEvent) async {
        started += 1
        for await _ in release.prefix(1) {}
    }
}

private actor ResourceProducerProgress {
    private(set) var chunksWritten = 0
    private(set) var stopped = false
    private(set) var cancelled = false
    func wroteChunk() { chunksWritten += 1 }
    func stop(cancelled: Bool) { stopped = true; self.cancelled = cancelled }
}

private func resourceStreamingApp(progress: ResourceProducerProgress) -> Application {
    Application {
        Get("/") { "ok" }
        Get("/large") {
            Response(body: .stream { writer in
                do {
                    let chunk = ByteChunk([UInt8](repeating: 97, count: 65_536))
                    for _ in 0..<4096 {
                        try await writer.write(chunk)
                        await progress.wroteChunk()
                    }
                    await progress.stop(cancelled: Task.isCancelled)
                } catch {
                    await progress.stop(cancelled: Task.isCancelled)
                    throw error
                }
            })
        }
    }
}
