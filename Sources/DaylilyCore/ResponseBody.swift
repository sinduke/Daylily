/// A buffered response or a one-shot, demand-driven response producer.
public struct ResponseBody: Sendable {
    public typealias Producer = @Sendable (ResponseBodyWriter) async throws -> Void

    private enum Storage: Sendable {
        case buffered([UInt8])
        case stream(ResponseProducer, length: Int?)
    }

    private let storage: Storage

    public static func bytes(_ bytes: [UInt8]) -> ResponseBody {
        ResponseBody(storage: .buffered(bytes))
    }

    /// The producer starts when the transport (or an explicit collector) consumes the body.
    /// Await each write before producing the next chunk. Copies share one-shot consumption.
    public static func stream(length: Int? = nil, _ producer: @escaping Producer) -> ResponseBody {
        precondition(length.map { $0 >= 0 } ?? true, "Response body length cannot be negative")
        return ResponseBody(storage: .stream(ResponseProducer(producer), length: length))
    }

    public var bufferedBytes: [UInt8]? {
        if case .buffered(let bytes) = storage { return bytes }
        return nil
    }

    public var isStreaming: Bool { bufferedBytes == nil }

    public var length: Int? {
        switch storage {
        case .buffered(let bytes): bytes.count
        case .stream(_, let length): length
        }
    }

    public func collect(upTo limit: ByteCount) async throws -> [UInt8] {
        let collector = ResponseBodyCollector(limit: limit)
        try await write { chunk in try await collector.append(chunk) }
        return await collector.bytes
    }

    @_spi(Transport)
    public func write(to sink: @escaping @Sendable (ByteChunk) async throws -> Void) async throws {
        try Task.checkCancellation()
        switch storage {
        case .buffered(let bytes):
            if !bytes.isEmpty { try await sink(ByteChunk(bytes)) }
        case .stream(let storage, let length):
            let producer = try await storage.consume()
            let state = ResponseWriterState(sink: sink, expectedLength: length)
            do {
                try await producer(ResponseBodyWriter(state: state))
                try Task.checkCancellation()
                try await state.finish()
            } catch {
                await state.abort()
                throw error
            }
        }
    }
}

/// An awaited write reaches the underlying consumer before the producer may continue.
public struct ResponseBodyWriter: Sendable {
    fileprivate let state: ResponseWriterState

    public func write(_ chunk: ByteChunk) async throws { try await state.write(chunk) }
    public func write(_ bytes: [UInt8]) async throws { try await write(ByteChunk(bytes)) }
    public func write(_ string: String) async throws { try await write(Array(string.utf8)) }
    public func write(_ event: ServerSentEvent) async throws { try await write(event.encoded) }
}

public enum ResponseBodyError: Error, Equatable, Sendable {
    case alreadyConsumed
    case tooLarge(limit: ByteCount)
    case lengthMismatch(expected: Int, actual: Int)
    case concurrentWrite
    case writerFinished
}

private actor ResponseProducer {
    private var producer: ResponseBody.Producer?

    init(_ producer: @escaping ResponseBody.Producer) { self.producer = producer }

    func consume() throws -> ResponseBody.Producer {
        guard let producer else { throw ResponseBodyError.alreadyConsumed }
        self.producer = nil
        return producer
    }
}

fileprivate actor ResponseWriterState {
    private let sink: @Sendable (ByteChunk) async throws -> Void
    private let expectedLength: Int?
    private var written = 0
    private var isWriting = false
    private var finished = false

    init(sink: @escaping @Sendable (ByteChunk) async throws -> Void, expectedLength: Int?) {
        self.sink = sink
        self.expectedLength = expectedLength
    }

    func write(_ chunk: ByteChunk) async throws {
        try Task.checkCancellation()
        guard !finished else { throw ResponseBodyError.writerFinished }
        guard !isWriting else { throw ResponseBodyError.concurrentWrite }
        guard !chunk.bytes.isEmpty else { return }
        if let expectedLength, chunk.count > expectedLength - written {
            throw ResponseBodyError.lengthMismatch(expected: expectedLength, actual: written + chunk.count)
        }
        isWriting = true
        defer { isWriting = false }
        try await sink(chunk)
        try Task.checkCancellation()
        guard !finished else { throw ResponseBodyError.writerFinished }
        written += chunk.count
    }

    func finish() throws {
        finished = true
        guard !isWriting else { throw ResponseBodyError.concurrentWrite }
        if let expectedLength, written != expectedLength {
            throw ResponseBodyError.lengthMismatch(expected: expectedLength, actual: written)
        }
    }

    func abort() { finished = true }
}

private actor ResponseBodyCollector {
    let limit: ByteCount
    private(set) var bytes: [UInt8] = []

    init(limit: ByteCount) { self.limit = limit }

    func append(_ chunk: ByteChunk) throws {
        guard chunk.count <= limit.bytes - bytes.count else {
            throw ResponseBodyError.tooLarge(limit: limit)
        }
        bytes.append(contentsOf: chunk.bytes)
    }
}

/// One UTF-8 server-sent event. Newlines in data become separate `data:` fields.
public struct ServerSentEvent: Equatable, Sendable {
    public var data: String
    public var id: String?
    public var event: String?
    public var retry: Int?

    public init(data: String, id: String? = nil, event: String? = nil, retry: Int? = nil) {
        precondition(retry.map { $0 >= 0 } ?? true, "SSE retry cannot be negative")
        self.data = data
        self.id = id
        self.event = event
        self.retry = retry
    }

    public var encoded: String {
        var result = ""
        if let id { result += "id: \(Self.singleLine(id))\n" }
        if let event { result += "event: \(Self.singleLine(event))\n" }
        if let retry, retry >= 0 { result += "retry: \(retry)\n" }
        // Swift treats CRLF as one Character; normalize all three line endings.
        let normalized = String(data.flatMap { character -> [Character] in
            character == "\r" || character == "\r\n" ? ["\n"] : [character]
        })
        for line in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
            result += "data: \(line)\n"
        }
        return result + "\n"
    }

    private static func singleLine(_ value: String) -> String {
        String(value.filter { $0 != "\n" && $0 != "\r" && $0 != "\r\n" && $0 != "\0" })
    }
}
