import DaylilyCore
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

    public func run() async throws {
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

        do {
            try await channel.closeFuture.get()
            try await group.shutdownGracefully()
        } catch {
            try? await group.shutdownGracefully()
            throw error
        }
    }
}

private final class DaylilyHTTPHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private let responder: @Sendable (Request) async -> Response
    private var head: HTTPRequestHead?
    private var body: [UInt8] = []

    init(responder: @escaping @Sendable (Request) async -> Response) {
        self.responder = responder
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        switch unwrapInboundIn(data) {
        case .head(let head):
            self.head = head
            self.body.removeAll(keepingCapacity: true)

        case .body(var buffer):
            if let bytes = buffer.readBytes(length: buffer.readableBytes) {
                self.body.append(contentsOf: bytes)
            }

        case .end:
            guard let head else {
                writeResponse(.text("Bad Request", status: .badRequest), context: context, keepAlive: false)
                return
            }

            let request = makeRequest(head: head, body: body)
            let keepAlive = head.isKeepAlive
            let responder = responder
            let loopBoundContext = context.loopBound

            context.eventLoop.makeFutureWithTask {
                await responder(request)
            }.whenComplete { [weak self] result in
                guard let self else {
                    loopBoundContext.value.close(promise: nil)
                    return
                }

                switch result {
                case .success(let response):
                    self.writeResponse(response, context: loopBoundContext.value, keepAlive: keepAlive)
                case .failure:
                    self.writeResponse(
                        .text("Internal Server Error", status: .internalServerError),
                        context: loopBoundContext.value,
                        keepAlive: keepAlive
                    )
                }
            }
        }
    }

    private func makeRequest(head: HTTPRequestHead, body: [UInt8]) -> Request {
        var headers = Headers()
        for (name, value) in head.headers {
            headers[name] = value
        }

        return Request(
            method: HTTPMethod(head.method.rawValue) ?? .get,
            path: Self.path(from: head.uri),
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

    private static func path(from uri: String) -> String {
        let path = uri.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? "/"
        return path.isEmpty ? "/" : path
    }
}
