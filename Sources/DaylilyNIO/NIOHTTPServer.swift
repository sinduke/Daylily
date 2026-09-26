@_spi(Transport) import DaylilyCore
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
import Dispatch
import NIOConcurrencyHelpers
import NIOCore
import NIOHTTP1
import NIOPosix

public struct NIOServerConfiguration: Sendable {
    public var host: String
    public var port: Int
    public var backlog: Int
    public var reuseAddress: Bool
    public var maxMessagesPerRead: Int
    public var gracefulShutdownSignals: Bool
    public var requestHeaderTimeout: Duration?
    public var uploadIdleTimeout: Duration?
    public var shutdownGracePeriod: Duration?

    public init(
        host: String = "127.0.0.1",
        port: Int = 8080,
        backlog: Int = 256,
        reuseAddress: Bool = true,
        maxMessagesPerRead: Int = 16,
        gracefulShutdownSignals: Bool = true,
        requestHeaderTimeout: Duration? = .seconds(15),
        uploadIdleTimeout: Duration? = .seconds(30),
        shutdownGracePeriod: Duration? = .seconds(10)
    ) {
        self.host = host
        self.port = port
        self.backlog = backlog
        self.reuseAddress = reuseAddress
        self.maxMessagesPerRead = maxMessagesPerRead
        self.gracefulShutdownSignals = gracefulShutdownSignals
        precondition(requestHeaderTimeout.map { $0 > .zero } ?? true, "Request header timeout must be positive")
        precondition(uploadIdleTimeout.map { $0 > .zero } ?? true, "Upload idle timeout must be positive")
        precondition(shutdownGracePeriod.map { $0 >= .zero } ?? true, "Shutdown grace period cannot be negative")
        self.requestHeaderTimeout = requestHeaderTimeout
        self.uploadIdleTimeout = uploadIdleTimeout
        self.shutdownGracePeriod = shutdownGracePeriod
    }

    public init(_ configuration: ServerConfiguration) {
        self.init(
            host: configuration.host,
            port: configuration.port,
            backlog: configuration.backlog,
            reuseAddress: configuration.reuseAddress,
            maxMessagesPerRead: configuration.maxMessagesPerRead,
            gracefulShutdownSignals: configuration.gracefulShutdownSignals,
            requestHeaderTimeout: configuration.requestHeaderTimeout,
            uploadIdleTimeout: configuration.uploadIdleTimeout,
            shutdownGracePeriod: configuration.shutdownGracePeriod
        )
    }
}

public struct NIOHTTPServer: Sendable {
    private let configuration: NIOServerConfiguration
    private let responder: @Sendable (Request) async -> Response
    private let responseObserver: (any ResponseTransferObserver)?

    public init(
        configuration: NIOServerConfiguration = NIOServerConfiguration(),
        responseObserver: (any ResponseTransferObserver)? = nil,
        responder: @escaping @Sendable (Request) async -> Response
    ) {
        self.configuration = configuration
        self.responder = responder
        self.responseObserver = responseObserver
    }

    public func run(
        started: @escaping @Sendable () async throws -> Void = {}
    ) async throws {
        let (shutdownRequests, continuation) = AsyncStream.makeStream(of: Void.self)
        continuation.finish()
        try await run(started: started, shutdownRequests: shutdownRequests)
    }

    @_spi(ServiceLifecycle)
    public func run(
        started: @escaping @Sendable () async throws -> Void = {},
        shutdownRequests: AsyncStream<Void>
    ) async throws {
        try Task.checkCancellation()
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        let connections = ServerConnections()

        let responder = responder
        let configuration = configuration
        let responseObserver = responseObserver
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: Int32(configuration.backlog))
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: configuration.reuseAddress ? 1 : 0)
            .childChannelInitializer { channel in
                let taskGate = ChannelTaskGate(eventLoop: channel.eventLoop)
                let connection = ManagedConnection(channel: channel, taskGate: taskGate)
                guard connections.insert(connection) else {
                    channel.close(promise: nil)
                    return channel.eventLoop.makeFailedFuture(ChannelError.ioOnClosedChannel)
                }
                channel.closeFuture.whenComplete { _ in
                    taskGate.close()
                    connections.remove(connection.id)
                }
                var encoderConfiguration = HTTPResponseEncoder.Configuration()
                encoderConfiguration.automaticallySetFramingHeaders = false
                return channel.pipeline.configureHTTPServerPipeline(withEncoderConfiguration: encoderConfiguration).flatMap {
                    channel.pipeline.addHandler(DaylilyHTTPHandler(
                        responder: responder,
                        taskGate: taskGate,
                        configuration: configuration,
                        responseObserver: responseObserver
                    ))
                }.map {
                    connection.initialized()
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: configuration.reuseAddress ? 1 : 0)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: UInt(configuration.maxMessagesPerRead))
            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())

        let channel: any Channel
        do {
            channel = try await bootstrap.bind(host: configuration.host, port: configuration.port).get()
        } catch {
            try? await group.shutdownGracefully()
            throw error
        }
        print("Daylily listening on http://\(configuration.host):\(configuration.port)")

        let closer = ChannelCloser(channel)
        let shutdown = ServerShutdown(closer: closer, connections: connections)
        let signalSources = configuration.gracefulShutdownSignals
            ? Self.installGracefulShutdownSignals(shutdown: shutdown)
            : []
        defer {
            for source in signalSources {
                source.cancel()
            }
        }

        let shutdownRequestTask = Task {
            for await _ in shutdownRequests {
                shutdown.graceful()
            }
        }
        defer {
            shutdownRequestTask.cancel()
        }

        do {
            try await withTaskCancellationHandler {
                try await started()
                try await channel.closeFuture.get()
                connections.beginDraining()
                let deadlineTask = configuration.shutdownGracePeriod.map { grace in
                    Task {
                        do {
                            try await Task.sleep(for: grace)
                            connections.forceClose()
                        } catch {}
                    }
                }
                await connections.waitUntilEmpty()
                deadlineTask?.cancel()
                await deadlineTask?.value
            } onCancel: {
                shutdown.force()
            }
            closer.stopScheduling()
            try await group.shutdownGracefully()
        } catch {
            shutdown.force()
            await connections.waitUntilEmpty()
            closer.stopScheduling()
            try? await group.shutdownGracefully()
            throw error
        }
    }

    private static func installGracefulShutdownSignals(shutdown: ServerShutdown) -> [DispatchSourceSignal] {
        let signals: [Int32] = [SIGINT, SIGTERM]

        return signals.map { signalNumber in
            signal(signalNumber, SIG_IGN)

            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .global())
            source.setEventHandler {
                shutdown.graceful()
            }
            source.resume()
            return source
        }
    }
}

private final class ServerShutdown: Sendable {
    let closer: ChannelCloser
    let connections: ServerConnections

    init(closer: ChannelCloser, connections: ServerConnections) {
        self.closer = closer
        self.connections = connections
    }

    func graceful() {
        connections.beginDraining()
        closer.close()
    }

    func force() {
        connections.forceClose()
        closer.close()
    }
}

private final class ServerConnections: Sendable {
    private struct State {
        var acceptsConnections = true
        var connections: [ObjectIdentifier: ManagedConnection] = [:]
        var waiters: [CheckedContinuation<Void, Never>] = []
    }
    private let state = NIOLockedValueBox(State())

    func insert(_ connection: ManagedConnection) -> Bool {
        state.withLockedValue { state in
            guard state.acceptsConnections else { return false }
            state.connections[connection.id] = connection
            return true
        }
    }

    func remove(_ id: ObjectIdentifier) {
        let waiters = state.withLockedValue { state in
            state.connections.removeValue(forKey: id)
            guard state.connections.isEmpty else { return [CheckedContinuation<Void, Never>]() }
            let waiters = state.waiters
            state.waiters.removeAll()
            return waiters
        }
        for waiter in waiters { waiter.resume() }
    }

    func beginDraining() {
        let connections = state.withLockedValue { state in
            guard state.acceptsConnections else { return [ManagedConnection]() }
            state.acceptsConnections = false
            return Array(state.connections.values)
        }
        for connection in connections { connection.quiesce() }
    }

    func forceClose() {
        let connections = state.withLockedValue { state in
            state.acceptsConnections = false
            return Array(state.connections.values)
        }
        for connection in connections { connection.close() }
    }

    func waitUntilEmpty() async {
        await withCheckedContinuation { continuation in
            let isEmpty = state.withLockedValue { state in
                if state.connections.isEmpty { return true }
                state.waiters.append(continuation)
                return false
            }
            if isEmpty { continuation.resume() }
        }
    }
}

/// Initialization and quiescing flags are confined to this connection's event loop.
private final class ManagedConnection: @unchecked Sendable {
    let channel: any Channel
    let taskGate: ChannelTaskGate
    var id: ObjectIdentifier { ObjectIdentifier(self) }
    private var isInitialized = false
    private var shouldQuiesce = false

    init(channel: any Channel, taskGate: ChannelTaskGate) {
        self.channel = channel
        self.taskGate = taskGate
    }

    func initialized() {
        isInitialized = true
        if shouldQuiesce { channel.pipeline.fireUserInboundEventTriggered(ChannelShouldQuiesceEvent()) }
    }

    func quiesce() {
        taskGate.execute {
            guard !self.shouldQuiesce else { return }
            self.shouldQuiesce = true
            if self.isInitialized { self.channel.pipeline.fireUserInboundEventTriggered(ChannelShouldQuiesceEvent()) }
        }
    }

    func close() { taskGate.execute { self.channel.close(promise: nil) } }
}

private final class ChannelCloser: @unchecked Sendable {
    private let taskGate: ChannelTaskGate
    private let channel: any Channel

    init(_ channel: any Channel) {
        self.taskGate = ChannelTaskGate(eventLoop: channel.eventLoop)
        self.channel = channel
    }

    func close() {
        taskGate.execute {
            self.channel.close(promise: nil as EventLoopPromise<Void>?)
        }
    }

    func stopScheduling() { taskGate.close() }
}

/// Task continuations can outlive channelInactive. Serialize the admission of new
/// event-loop work with channel teardown so they never touch a stopped event loop.
private final class ChannelTaskGate: Sendable {
    private let isOpen = NIOLockedValueBox(true)
    private let eventLoop: any EventLoop

    init(eventLoop: any EventLoop) { self.eventLoop = eventLoop }

    @discardableResult
    func execute(_ operation: @escaping @Sendable () -> Void) -> Bool {
        isOpen.withLockedValue { isOpen in
            guard isOpen else { return false }
            eventLoop.execute(operation)
            return true
        }
    }

    func close() { isOpen.withLockedValue { $0 = false } }

    func perform(
        _ operation: @escaping @Sendable (CheckedContinuation<Void, any Error>) -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            guard execute({ operation(continuation) }) else {
                continuation.resume(throwing: CancellationError())
                return
            }
        }
    }
}

private final class DaylilyHTTPHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private let responder: @Sendable (Request) async -> Response
    private let taskGate: ChannelTaskGate
    private let configuration: NIOServerConfiguration
    private let responseObserver: (any ResponseTransferObserver)?
    private var currentRequest: CurrentRequest?
    private var nextRequestID = 0
    private var responseTask: Task<Void, Never>?
    private var headerDeadline: Scheduled<Void>?
    private var uploadDeadline: Scheduled<Void>?
    private var nextTransferID = 0
    private var transfers: [Int: ResponseTransferState] = [:]

    init(
        responder: @escaping @Sendable (Request) async -> Response,
        taskGate: ChannelTaskGate,
        configuration: NIOServerConfiguration,
        responseObserver: (any ResponseTransferObserver)?
    ) {
        self.responder = responder
        self.taskGate = taskGate
        self.configuration = configuration
        self.responseObserver = responseObserver
    }

    func channelActive(context: ChannelHandlerContext) {
        startHeaderDeadline(context: context)
        context.fireChannelActive()
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        switch unwrapInboundIn(data) {
        case .head(let head):
            startRequest(head: head, context: context)

        case .body(var buffer):
            if let bytes = buffer.readBytes(length: buffer.readableBytes) {
                receiveBodyChunk(ByteChunk(bytes), context: context)
            }

        case .end:
            finishRequestBody(context: context)
        }
    }

    func errorCaught(context: ChannelHandlerContext, error: any Error) {
        currentRequest?.handlerTask?.cancel()
        responseTask?.cancel()
        failBodyStream()
        context.close(promise: nil)
    }

    func channelInactive(context: ChannelHandlerContext) {
        cancelReadDeadlines()
        taskGate.close()
        currentRequest?.handlerTask?.cancel()
        responseTask?.cancel()
        responseTask = nil
        failBodyStream()
        currentRequest = nil
        for transfer in transfers.values where !transfer.ending {
            transfer.finish(.cancelled)
        }
        transfers = transfers.filter { $0.value.ending }
    }

    func handlerRemoved(context: ChannelHandlerContext) {
        cancelReadDeadlines()
        taskGate.close()
    }

    private func startRequest(head: HTTPRequestHead, context: ChannelHandlerContext) {
        headerDeadline?.cancel()
        headerDeadline = nil
        guard currentRequest == nil else {
            currentRequest?.handlerTask?.cancel()
            currentRequest?.responseWritten = true
            failBodyStream()
            writeResponse(.text("Bad Request", status: .badRequest), context: context, keepAlive: false)
            return
        }

        guard let method = DaylilyCore.HTTPMethod(head.method.rawValue) else {
            writeResponse(.text("Bad Request", status: .badRequest), context: context, keepAlive: false)
            return
        }

        let stream = RequestBody.stream()
        let request = makeRequest(head: head, method: method, body: stream.body)
        nextRequestID &+= 1
        let requestID = nextRequestID
        let current = CurrentRequest(id: requestID, head: head, request: request, writer: stream.writer)
        currentRequest = current
        restartUploadDeadline(context: context)

        let responder = responder
        let loopBoundContext = context.loopBound
        let taskGate = taskGate

        current.handlerTask = Task {
            guard !Task.isCancelled else { return }
            let response = await responder(request)
            guard !Task.isCancelled else { return }
            taskGate.execute { [weak self] in
                guard let self else { return }
                guard self.currentRequest?.id == requestID, loopBoundContext.value.channel.isActive else { return }
                self.currentRequest?.handlerTask = nil
                self.responderFinished(response, context: loopBoundContext.value)
            }
        }
    }

    private func receiveBodyChunk(_ chunk: ByteChunk, context: ChannelHandlerContext) {
        guard let current = currentRequest, !current.responseWritten else {
            return
        }

        current.pendingChunks.append(chunk)
        restartUploadDeadline(context: context)
        pumpBodyWrites(context: context)
    }

    private func finishRequestBody(context: ChannelHandlerContext) {
        guard let current = currentRequest else {
            writeResponse(.text("Bad Request", status: .badRequest), context: context, keepAlive: false)
            return
        }

        current.didReceiveEnd = true
        uploadDeadline?.cancel()
        uploadDeadline = nil
        finishBodyWriterIfReady(context: context)
        writeReadyResponseIfPossible(context: context)

        // HTTPServerPipelineHandler suppresses reads while a response is pending.
        // On Darwin, NIO cannot observe EOF without a read registered, so an idle
        // disconnected client would otherwise leave a suspended handler running.
        // Request one read upstream of the pipelining handler. It still buffers
        // pipelined requests in order, and this does not enable unlimited prefetch.
        context.pipeline.context(handlerType: HTTPServerPipelineHandler.self).whenSuccess { pipelineContext in
            guard pipelineContext.channel.isActive else { return }
            pipelineContext.read()
        }
    }

    private func pumpBodyWrites(context: ChannelHandlerContext) {
        guard let current = currentRequest else {
            return
        }

        guard !current.isWritingBody, !current.pendingChunks.isEmpty, !current.responseWritten else {
            finishBodyWriterIfReady(context: context)
            return
        }

        let chunk = current.pendingChunks.removeFirst()
        current.isWritingBody = true
        pauseReads(context: context)

        let writer = current.writer
        let requestID = current.id
        let loopBoundContext = context.loopBound
        let taskGate = taskGate

        Task {
            let accepted = await writer.write(chunk)
            taskGate.execute { [weak self] in
                guard let self else { return }
                guard self.currentRequest?.id == requestID else { return }
                self.bodyWriteFinished(result: .success(accepted), context: loopBoundContext.value)
            }
        }
    }

    private func bodyWriteFinished(result: Result<Bool, any Error>, context: ChannelHandlerContext) {
        guard let current = currentRequest else {
            return
        }

        current.isWritingBody = false

        switch result {
        case .success:
            break
        case .failure:
            failBodyStream()
            writeResponse(.text("Bad Request", status: .badRequest), context: context, keepAlive: false)
            return
        }

        if current.pendingChunks.isEmpty, !current.responseWritten {
            resumeReads(context: context)
        }

        finishBodyWriterIfReady(context: context)
        pumpBodyWrites(context: context)
    }

    private func finishBodyWriterIfReady(context: ChannelHandlerContext) {
        guard let current = currentRequest,
              current.didReceiveEnd,
              !current.didFinishWriter,
              !current.isWritingBody,
              current.pendingChunks.isEmpty
        else {
            return
        }

        current.didFinishWriter = true
        let writer = current.writer

        Task {
            await writer.finish()
        }
    }

    private func responderFinished(_ response: Response, context: ChannelHandlerContext) {
        guard let current = currentRequest else {
            writeResponse(response, context: context, keepAlive: false)
            return
        }

        current.readyResponse = response

        if !current.didReceiveEnd, !current.mayHaveBody {
            return
        }

        writeReadyResponseIfPossible(context: context)
    }

    private func writeReadyResponseIfPossible(context: ChannelHandlerContext) {
        guard let current = currentRequest,
              let response = current.readyResponse,
              !current.responseWritten
        else {
            return
        }

        current.responseWritten = true

        if !current.didReceiveEnd {
            // An early response abandons the remaining upload and closes afterward.
            // Its producer must not inherit the abandoned request's idle deadline.
            uploadDeadline?.cancel()
            uploadDeadline = nil
            let writer = current.writer
            Task {
                await writer.cancel()
            }
        } else if !current.didFinishWriter {
            current.pendingChunks.removeAll(keepingCapacity: false)
            current.didFinishWriter = true

            let writer = current.writer
            Task {
                await writer.cancel()
            }
        }

        let asksToClose = response.headers.values(for: "connection").contains { value in
            value.split(separator: ",").contains { token in
                let parts = token.split(whereSeparator: { $0 == " " || $0 == "\t" })
                return parts.count == 1 && parts[0].lowercased() == "close"
            }
        }
        let keepAlive = current.keepAlive && current.didReceiveEnd && !asksToClose
        writeResponse(response, context: context, keepAlive: keepAlive)
    }

    private func failBodyStream() {
        guard let current = currentRequest else {
            return
        }

        let writer = current.writer
        Task {
            await writer.fail()
        }
    }

    private func pauseReads(context: ChannelHandlerContext) {
        guard let current = currentRequest, !current.readsPaused else {
            return
        }

        current.readsPaused = true
        uploadDeadline?.cancel()
        uploadDeadline = nil
        let loopBoundContext = context.loopBound

        context.channel.setOption(ChannelOptions.autoRead, value: false).whenFailure { _ in
            loopBoundContext.value.close(promise: nil)
        }
    }

    private func resumeReads(context: ChannelHandlerContext) {
        guard let current = currentRequest, current.readsPaused, !current.responseWritten else {
            return
        }

        current.readsPaused = false
        restartUploadDeadline(context: context)
        let loopBoundContext = context.loopBound

        context.channel.setOption(ChannelOptions.autoRead, value: true).whenComplete { _ in
            loopBoundContext.value.read()
        }
    }

    private func makeRequest(head: HTTPRequestHead, method: DaylilyCore.HTTPMethod, body: RequestBody) -> Request {
        var headers = Headers()
        for (name, value) in head.headers {
            headers.add(name: name, value: value)
        }

        return Request(
            method: method,
            path: Self.requestTarget(from: head.uri),
            headers: headers,
            body: body
        )
    }

    private func startHeaderDeadline(context: ChannelHandlerContext) {
        headerDeadline?.cancel()
        headerDeadline = nil
        guard currentRequest == nil, context.channel.isActive,
              let timeout = configuration.requestHeaderTimeout else { return }
        let loopBoundContext = context.loopBound
        headerDeadline = context.eventLoop.scheduleTask(in: Self.timeAmount(timeout)) { [weak self] in
            guard let self, self.currentRequest == nil else { return }
            self.headerDeadline = nil
            // A partial head has not yet reached the HTTP pipeline's request state.
            // Close directly instead of manufacturing an invalid unsolicited response.
            loopBoundContext.value.close(promise: nil)
        }
    }

    private func restartUploadDeadline(context: ChannelHandlerContext) {
        uploadDeadline?.cancel()
        uploadDeadline = nil
        guard let current = currentRequest, current.mayHaveBody,
              !current.didReceiveEnd, !current.readsPaused,
              let timeout = configuration.uploadIdleTimeout else { return }
        let requestID = current.id
        let loopBoundContext = context.loopBound
        uploadDeadline = context.eventLoop.scheduleTask(in: Self.timeAmount(timeout)) { [weak self] in
            guard let self, let current = self.currentRequest, current.id == requestID,
                  !current.didReceiveEnd, !current.readsPaused else { return }
            self.uploadDeadline = nil
            current.handlerTask?.cancel()
            self.failBodyStream()
            let context = loopBoundContext.value
            if current.responseWritten || self.responseTask != nil {
                context.close(promise: nil)
            } else {
                current.responseWritten = true
                self.writeResponse(
                    .text("Request Timeout", status: Status(408, reasonPhrase: "Request Timeout")),
                    context: context,
                    keepAlive: false
                )
            }
        }
    }

    private func cancelReadDeadlines() {
        headerDeadline?.cancel()
        uploadDeadline?.cancel()
        headerDeadline = nil
        uploadDeadline = nil
    }

    private static func timeAmount(_ duration: Duration) -> TimeAmount {
        let components = duration.components
        let seconds = components.seconds.multipliedReportingOverflow(by: 1_000_000_000)
        guard !seconds.overflow else { return .nanoseconds(.max) }
        let nanos = seconds.partialValue.addingReportingOverflow(components.attoseconds / 1_000_000_000)
        return .nanoseconds(nanos.overflow ? .max : max(1, nanos.partialValue))
    }

    private func writeResponse(_ response: Response, context: ChannelHandlerContext, keepAlive: Bool) {
        guard context.channel.isActive else { return }
        // A protocol failure can arrive while a response producer is suspended.
        // Never replace its task or write a second response into the active body.
        guard responseTask == nil else {
            currentRequest?.handlerTask?.cancel()
            responseTask?.cancel()
            failBodyStream()
            context.close(promise: nil)
            return
        }
        let loopBoundContext = context.loopBound
        let channel = context.channel
        let taskGate = taskGate
        let requestID = currentRequest?.id
        let isHead = currentRequest?.method == .HEAD
        let status = response.status.code
        let forbidsBody = (100..<200).contains(status) || status == 204 || status == 304
        let suppressBody = isHead || forbidsBody
        nextTransferID &+= 1
        let transferID = nextTransferID
        let transfer = responseObserver.map {
            ResponseTransferState(
                observer: $0,
                method: currentRequest?.requestMethod,
                path: currentRequest?.path,
                status: response.status,
                requestID: response.headers["x-daylily-request-id"],
                correlationID: currentRequest?.correlationID
            )
        }
        if let transfer { transfers[transferID] = transfer }
        var headers = HTTPHeaders()
        for (name, value) in response.headers.all {
            headers.add(name: name, value: value)
        }
        // Framing is owned by the transport. Never emit conflicting transfer encodings.
        headers.remove(name: "transfer-encoding")
        if (100..<200).contains(status) || status == 204 {
            headers.remove(name: "content-length")
        } else if status == 304 {
            // An explicitly supplied 304 length describes the selected representation.
        } else if isHead {
            // HEAD may describe a representation without constructing its body.
            // Preserve an explicit length, otherwise infer it without starting a stream.
            if !headers.contains(name: "content-length"), let length = response.responseBody.length {
                headers.add(name: "content-length", value: "\(length)")
            }
        } else if let length = response.responseBody.length {
            headers.replaceOrAdd(name: "content-length", value: "\(length)")
        } else {
            headers.remove(name: "content-length")
            headers.add(name: "transfer-encoding", value: "chunked")
        }
        headers.replaceOrAdd(name: "connection", value: keepAlive ? "keep-alive" : "close")

        let head = HTTPResponseHead(
            version: .http1_1,
            status: HTTPResponseStatus(statusCode: response.status.code),
            headers: headers
        )

        responseTask = Task {
            do {
                try Task.checkCancellation()
                try await taskGate.perform { continuation in
                    channel.writeAndFlush(HTTPServerResponsePart.head(head)).whenComplete {
                        continuation.resume(with: $0)
                    }
                }
                if !suppressBody {
                    try await response.responseBody.write { chunk in
                        try Task.checkCancellation()
                        var buffer = channel.allocator.buffer(capacity: chunk.count)
                        buffer.writeBytes(chunk.bytes)
                        // A completed write promise means this chunk has left NIO's pending
                        // write queue. Await it before pulling more bytes from the producer.
                        let chunkBuffer = buffer
                        try await taskGate.perform { continuation in
                            channel.writeAndFlush(HTTPServerResponsePart.body(.byteBuffer(chunkBuffer))).whenComplete {
                                if case .success = $0 { transfer?.addBytes(chunk.count) }
                                continuation.resume(with: $0)
                            }
                        }
                        try Task.checkCancellation()
                    }
                }
                try Task.checkCancellation()
                try await taskGate.perform { [weak self] continuation in
                    // Work admitted before channelInactive may still be queued.
                    // Do not write through a context whose pipeline is now removed.
                    guard let self, channel.isActive else {
                        continuation.resume(throwing: ChannelError.ioOnClosedChannel)
                        return
                    }
                    let context = loopBoundContext.value
                    transfer?.ending = true
                    // Clear the completed request before .end releases the next pipelined
                    // request from NIO's HTTPServerPipelineHandler.
                    if let requestID, self.currentRequest?.id == requestID {
                        let readsPaused = self.currentRequest?.readsPaused == true
                        self.currentRequest = nil
                        self.responseTask = nil
                        if keepAlive && readsPaused {
                            context.channel.setOption(ChannelOptions.autoRead, value: true).whenFailure { _ in
                                loopBoundContext.value.close(promise: nil)
                            }
                        }
                    }
                    context.writeAndFlush(self.wrapOutboundOut(.end(nil))).whenComplete {
                        switch $0 {
                        case .success:
                            transfer?.finish(.completed)
                            // The next header budget starts after response framing flushes.
                            // A queued next request may already have populated currentRequest.
                            self.startHeaderDeadline(context: context)
                        case .failure: transfer?.finish(channel.isActive ? .failed : .cancelled)
                        }
                        self.transfers.removeValue(forKey: transferID)
                        continuation.resume(with: $0)
                    }
                }
                if !keepAlive { taskGate.execute { channel.close(promise: nil) } }
            } catch {
                // Headers may already have reached the peer. A second HTTP error response
                // would corrupt framing; closing also unblocks a pending socket write.
                let outcome: ResponseTransferOutcome = Task.isCancelled || error is CancellationError ? .cancelled : .failed
                taskGate.execute { [weak self] in
                    transfer?.finish(outcome)
                    self?.transfers.removeValue(forKey: transferID)
                    channel.close(promise: nil)
                }
            }
        }
    }

    private static func requestTarget(from uri: String) -> String {
        uri.isEmpty ? "/" : uri
    }
}

/// Mutable accounting is confined to the connection's event loop. Delivery uses
/// an immutable snapshot on a Swift task and never delays socket or shutdown work.
private final class ResponseTransferState: @unchecked Sendable {
    let observer: any ResponseTransferObserver
    let method: DaylilyCore.HTTPMethod?
    let path: String?
    let status: Status
    let requestID: String?
    let correlationID: String?
    let started = DispatchTime.now().uptimeNanoseconds
    var ending = false
    private var isTerminal = false
    private var bytesSent = 0

    init(observer: any ResponseTransferObserver, method: DaylilyCore.HTTPMethod?, path: String?, status: Status, requestID: String?, correlationID: String?) {
        self.observer = observer
        self.method = method
        self.path = path
        self.status = status
        self.requestID = requestID
        self.correlationID = correlationID
    }

    func addBytes(_ count: Int) {
        guard !isTerminal else { return }
        bytesSent += count
    }

    func finish(_ outcome: ResponseTransferOutcome) {
        guard !isTerminal else { return }
        isTerminal = true
        let event = ResponseTransferEvent(
            method: method,
            path: path,
            status: status,
            requestID: requestID,
            correlationID: correlationID,
            bytesSent: bytesSent,
            durationNanoseconds: DispatchTime.now().uptimeNanoseconds &- started,
            outcome: outcome
        )
        let observer = observer
        Task { await observer.record(event) }
    }
}

private final class CurrentRequest {
    let id: Int
    let writer: BodyStreamWriter
    let keepAlive: Bool
    let method: NIOHTTP1.HTTPMethod
    let requestMethod: DaylilyCore.HTTPMethod
    let path: String
    let correlationID: String?
    var handlerTask: Task<Void, Never>?
    var pendingChunks: [ByteChunk] = []
    var isWritingBody = false
    var didReceiveEnd = false
    var didFinishWriter = false
    var readsPaused = false
    var responseWritten = false
    var readyResponse: Response?
    let mayHaveBody: Bool

    init(id: Int, head: HTTPRequestHead, request: Request, writer: BodyStreamWriter) {
        self.id = id
        self.writer = writer
        self.keepAlive = head.isKeepAlive
        self.method = head.method
        self.requestMethod = request.method
        self.path = request.path
        self.correlationID = request.headers["x-request-id"]
        self.mayHaveBody = Self.requestMayHaveBody(head)
    }

    private static func requestMayHaveBody(_ head: HTTPRequestHead) -> Bool {
        if head.headers.contains(name: "transfer-encoding") {
            return true
        }

        return head.headers["content-length"].contains { value in
            (Int(value) ?? 0) > 0
        }
    }
}
