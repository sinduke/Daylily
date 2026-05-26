@_spi(Transport) import DaylilyCore
import Darwin
import Dispatch
import NIOCore
import NIOHTTP1
import NIOPosix

public struct NIOServerConfiguration: Sendable {
    public var host: String
    public var port: Int

    public init(host: String = "127.0.0.1", port: Int = 8080) {
        self.host = host
        self.port = port
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
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

        let responder = responder
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(DaylilyHTTPHandler(responder: responder))
                }
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())

        let channel = try await bootstrap.bind(host: configuration.host, port: configuration.port).get()
        print("Daylily listening on http://\(configuration.host):\(configuration.port)")

        let signalSources = Self.installGracefulShutdownSignals(on: channel)
        defer {
            for source in signalSources {
                source.cancel()
            }
        }

        do {
            try await started()
            try await channel.closeFuture.get()
            try await group.shutdownGracefully()
        } catch {
            channel.close(promise: nil)
            try? await group.shutdownGracefully()
            throw error
        }
    }

    private static func installGracefulShutdownSignals(on channel: any Channel) -> [DispatchSourceSignal] {
        let eventLoop = channel.eventLoop
        let signals: [Int32] = [SIGINT, SIGTERM]

        return signals.map { signalNumber in
            signal(signalNumber, SIG_IGN)

            let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .global())
            source.setEventHandler {
                eventLoop.execute {
                    channel.close(promise: nil)
                }
            }
            source.resume()
            return source
        }
    }
}

private final class DaylilyHTTPHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private let responder: @Sendable (Request) async -> Response
    private var currentRequest: CurrentRequest?

    init(responder: @escaping @Sendable (Request) async -> Response) {
        self.responder = responder
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
        failBodyStream()
        context.close(promise: nil)
    }

    func channelInactive(context: ChannelHandlerContext) {
        failBodyStream()
        currentRequest = nil
    }

    private func startRequest(head: HTTPRequestHead, context: ChannelHandlerContext) {
        guard currentRequest == nil else {
            failBodyStream()
            writeResponse(.text("Bad Request", status: .badRequest), context: context, keepAlive: false)
            return
        }

        let stream = Body.stream()
        let request = makeRequest(head: head, body: stream.body)
        let current = CurrentRequest(head: head, writer: stream.writer)
        currentRequest = current

        let responder = responder
        let loopBoundContext = context.loopBound

        context.eventLoop.makeFutureWithTask {
            await responder(request)
        }.whenComplete { [weak self] result in
            guard let self else {
                loopBoundContext.value.close(promise: nil)
                return
            }

            let response: Response
            switch result {
            case .success(let value):
                response = value
            case .failure:
                response = .text("Internal Server Error", status: .internalServerError)
            }

            self.responderFinished(response, context: loopBoundContext.value)
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
        let loopBoundContext = context.loopBound

        context.eventLoop.makeFutureWithTask {
            await writer.write(chunk)
        }.whenComplete { [weak self] result in
            guard let self else {
                loopBoundContext.value.close(promise: nil)
                return
            }

            self.bodyWriteFinished(result: result, context: loopBoundContext.value)
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

        context.eventLoop.makeFutureWithTask {
            await writer.finish()
        }.whenComplete { _ in }
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
            context.eventLoop.makeFutureWithTask {
                await writer.cancel()
            }.whenComplete { _ in }
        } else if !current.didFinishWriter {
            current.pendingChunks.removeAll(keepingCapacity: false)
            current.didFinishWriter = true

            let writer = current.writer
            context.eventLoop.makeFutureWithTask {
                await writer.cancel()
            }.whenComplete { _ in }
        }

        let keepAlive = current.keepAlive && current.didReceiveEnd
        writeResponse(response, context: context, keepAlive: keepAlive)

        if keepAlive {
            currentRequest = nil
        }
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

    private func makeRequest(head: HTTPRequestHead, body: Body) -> Request {
        var headers = Headers()
        for (name, value) in head.headers {
            headers[name] = value
        }

        return Request(
            method: HTTPMethod(head.method.rawValue) ?? .get,
            path: Self.requestTarget(from: head.uri),
            headers: headers,
            body: body
        )
    }

    private func writeResponse(_ response: Response, context: ChannelHandlerContext, keepAlive: Bool) {
        let loopBoundContext = context.loopBound
        var headers = HTTPHeaders()
        for (name, value) in response.headers.all {
            headers.add(name: name, value: value)
        }
        if !headers.contains(name: "content-length") {
            headers.add(name: "content-length", value: "\(response.body.count)")
        }
        if keepAlive {
            headers.add(name: "connection", value: "keep-alive")
        }

        let head = HTTPResponseHead(
            version: .http1_1,
            status: HTTPResponseStatus(statusCode: response.status.code),
            headers: headers
        )

        context.write(wrapOutboundOut(.head(head)), promise: nil)

        if !response.body.isEmpty {
            var buffer = context.channel.allocator.buffer(capacity: response.body.count)
            buffer.writeBytes(response.body)
            context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        }

        context.writeAndFlush(wrapOutboundOut(.end(nil))).whenComplete { _ in
            if !keepAlive {
                loopBoundContext.value.close(promise: nil)
            }
        }
    }

    private static func requestTarget(from uri: String) -> String {
        uri.isEmpty ? "/" : uri
    }
}

private final class CurrentRequest {
    let writer: BodyStreamWriter
    let keepAlive: Bool
    var pendingChunks: [ByteChunk] = []
    var isWritingBody = false
    var didReceiveEnd = false
    var didFinishWriter = false
    var readsPaused = false
    var responseWritten = false
    var readyResponse: Response?
    let mayHaveBody: Bool

    init(head: HTTPRequestHead, writer: BodyStreamWriter) {
        self.writer = writer
        self.keepAlive = head.isKeepAlive
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
