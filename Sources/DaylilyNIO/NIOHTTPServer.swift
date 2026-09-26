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

    public init(
        host: String = "127.0.0.1",
        port: Int = 8080,
        backlog: Int = 256,
        reuseAddress: Bool = true,
        maxMessagesPerRead: Int = 16,
        gracefulShutdownSignals: Bool = true
    ) {
        self.host = host
        self.port = port
        self.backlog = backlog
        self.reuseAddress = reuseAddress
        self.maxMessagesPerRead = maxMessagesPerRead
        self.gracefulShutdownSignals = gracefulShutdownSignals
    }

    public init(_ configuration: ServerConfiguration) {
        self.init(
            host: configuration.host,
            port: configuration.port,
            backlog: configuration.backlog,
            reuseAddress: configuration.reuseAddress,
            maxMessagesPerRead: configuration.maxMessagesPerRead,
            gracefulShutdownSignals: configuration.gracefulShutdownSignals
        )
    }
}

public struct NIOHTTPServer: Sendable {
    private let configuration: NIOServerConfiguration
    private let responder: @Sendable (Request) async -> Response

    public init(
        configuration: NIOServerConfiguration = NIOServerConfiguration(),
        responder: @escaping @Sendable (Request) async -> Response
    ) {
        self.configuration = configuration
        self.responder = responder
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
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

        let responder = responder
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: Int32(configuration.backlog))
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: configuration.reuseAddress ? 1 : 0)
            .childChannelInitializer { channel in
                var encoderConfiguration = HTTPResponseEncoder.Configuration()
                encoderConfiguration.automaticallySetFramingHeaders = false
                return channel.pipeline.configureHTTPServerPipeline(withEncoderConfiguration: encoderConfiguration).flatMap {
                    channel.pipeline.addHandler(DaylilyHTTPHandler(
                        responder: responder,
                        taskGate: ChannelTaskGate(eventLoop: channel.eventLoop)
                    ))
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
        let signalSources = configuration.gracefulShutdownSignals
            ? Self.installGracefulShutdownSignals(closer: closer)
            : []
        defer {
            for source in signalSources {
                source.cancel()
            }
        }

        let shutdownRequestTask = Task {
            for await _ in shutdownRequests {
                closer.close()
                return
            }
        }
        defer {
            shutdownRequestTask.cancel()
        }

        do {
            try await withTaskCancellationHandler {
                try await started()
                try await channel.closeFuture.get()
            } onCancel: {
                closer.close()
            }
            closer.stopScheduling()
            try await group.shutdownGracefully()
        } catch {
            closer.close()
            closer.stopScheduling()
            try? await group.shutdownGracefully()
            throw error
        }
    }

    private static func installGracefulShutdownSignals(closer: ChannelCloser) -> [DispatchSourceSignal] {
        let signals: [Int32] = [SIGINT, SIGTERM]

        return signals.map { signalNumber in
            signal(signalNumber, SIG_IGN)

            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .global())
            source.setEventHandler {
                closer.close()
            }
            source.resume()
            return source
        }
    }
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
    private var currentRequest: CurrentRequest?
    private var nextRequestID = 0
    private var responseTask: Task<Void, Never>?

    init(responder: @escaping @Sendable (Request) async -> Response, taskGate: ChannelTaskGate) {
        self.responder = responder
        self.taskGate = taskGate
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
        taskGate.close()
        currentRequest?.handlerTask?.cancel()
        responseTask?.cancel()
        responseTask = nil
        failBodyStream()
        currentRequest = nil
    }

    func handlerRemoved(context: ChannelHandlerContext) {
        taskGate.close()
    }

    private func startRequest(head: HTTPRequestHead, context: ChannelHandlerContext) {
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
        let current = CurrentRequest(id: requestID, head: head, writer: stream.writer)
        currentRequest = current

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
        pumpBodyWrites(context: context)
    }

    private func finishRequestBody(context: ChannelHandlerContext) {
        guard let current = currentRequest else {
            writeResponse(.text("Bad Request", status: .badRequest), context: context, keepAlive: false)
            return
        }

        current.didReceiveEnd = true
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
                        continuation.resume(with: $0)
                    }
                }
                if !keepAlive { taskGate.execute { channel.close(promise: nil) } }
            } catch {
                // Headers may already have reached the peer. A second HTTP error response
                // would corrupt framing; closing also unblocks a pending socket write.
                taskGate.execute { channel.close(promise: nil) }
            }
        }
    }

    private static func requestTarget(from uri: String) -> String {
        uri.isEmpty ? "/" : uri
    }
}

private final class CurrentRequest {
    let id: Int
    let writer: BodyStreamWriter
    let keepAlive: Bool
    let method: NIOHTTP1.HTTPMethod
    var handlerTask: Task<Void, Never>?
    var pendingChunks: [ByteChunk] = []
    var isWritingBody = false
    var didReceiveEnd = false
    var didFinishWriter = false
    var readsPaused = false
    var responseWritten = false
    var readyResponse: Response?
    let mayHaveBody: Bool

    init(id: Int, head: HTTPRequestHead, writer: BodyStreamWriter) {
        self.id = id
        self.writer = writer
        self.keepAlive = head.isKeepAlive
        self.method = head.method
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
