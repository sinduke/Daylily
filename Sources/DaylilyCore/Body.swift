public struct ByteCount: Comparable, Sendable {
    public let bytes: Int

    public init(bytes: Int) {
        precondition(bytes >= 0, "ByteCount cannot be negative")
        self.bytes = bytes
    }

    public static func bytes(_ value: Int) -> ByteCount {
        ByteCount(bytes: value)
    }

    public static func kilobytes(_ value: Int) -> ByteCount {
        scaled(value, by: 1024)
    }

    public static func megabytes(_ value: Int) -> ByteCount {
        scaled(value, by: 1024 * 1024)
    }

    public static func gigabytes(_ value: Int) -> ByteCount {
        scaled(value, by: 1024 * 1024 * 1024)
    }

    public static func < (lhs: ByteCount, rhs: ByteCount) -> Bool {
        lhs.bytes < rhs.bytes
    }

    private static func scaled(_ value: Int, by multiplier: Int) -> ByteCount {
        precondition(value >= 0, "ByteCount cannot be negative")
        let result = value.multipliedReportingOverflow(by: multiplier)
        precondition(!result.overflow, "ByteCount overflow")
        return ByteCount(bytes: result.partialValue)
    }
}

public struct ByteChunk: Sendable {
    public let bytes: [UInt8]

    public init(_ bytes: [UInt8]) {
        self.bytes = bytes
    }

    public var count: Int {
        bytes.count
    }
}

public struct RequestBody: Sendable {
    private let storage: BodyStorage

    private init(storage: BodyStorage) {
        self.storage = storage
    }

    public static func bytes(_ bytes: [UInt8]) -> RequestBody {
        RequestBody(storage: BodyStorage(source: .buffered(bytes)))
    }

    @_spi(Transport)
    public static func stream(bufferLimit: ByteCount = .megabytes(1)) -> BodyStream {
        let storage = BodyStreamStorage(bufferLimit: bufferLimit)
        return BodyStream(
            body: RequestBody(storage: BodyStorage(source: .stream(storage))),
            writer: BodyStreamWriter(storage: storage)
        )
    }

    public var bytes: BodyBytes {
        BodyBytes(storage: storage)
    }

    public func collect(upTo limit: ByteCount) async throws -> [UInt8] {
        var collected: [UInt8] = []
        collected.reserveCapacity(min(limit.bytes, 1024))

        for try await chunk in bytes {
            if chunk.count > limit.bytes - collected.count {
                throw BodyError.tooLarge(limit: limit)
            }

            collected.append(contentsOf: chunk.bytes)
        }

        return collected
    }

    public func string(upTo limit: ByteCount) async throws -> String {
        let bytes = try await collect(upTo: limit)
        guard UTF8Validator.isValid(bytes) else {
            throw BodyError.invalidEncoding
        }

        return String(decoding: bytes, as: UTF8.self)
    }
}

@_spi(Transport)
public struct BodyStream: Sendable {
    public let body: RequestBody
    public let writer: BodyStreamWriter
}

@_spi(Transport)
public struct BodyStreamWriter: Sendable {
    private let storage: BodyStreamStorage

    fileprivate init(storage: BodyStreamStorage) {
        self.storage = storage
    }

    @discardableResult
    public func write(_ chunk: ByteChunk) async -> Bool {
        await storage.write(chunk)
    }

    public func finish() async {
        await storage.finish()
    }

    public func fail() async {
        await storage.fail()
    }

    public func cancel() async {
        await storage.cancel()
    }
}

public struct BodyBytes: AsyncSequence, Sendable {
    public typealias Element = ByteChunk

    private let storage: BodyStorage

    fileprivate init(storage: BodyStorage) {
        self.storage = storage
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(storage: storage)
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private var storage: BodyStorage?
        private var consumer: BodyConsumer?

        fileprivate init(storage: BodyStorage) {
            self.storage = storage
        }

        public mutating func next() async throws -> ByteChunk? {
            if consumer == nil, let storage {
                consumer = try await storage.consume()
                self.storage = nil
            }

            return try await consumer?.next()
        }
    }
}

public enum BodyError: ResponseError {
    case alreadyConsumed
    case tooLarge(limit: ByteCount)
    case streamFailed
    case invalidEncoding

    public var status: Status {
        switch self {
        case .alreadyConsumed:
            .internalServerError
        case .tooLarge:
            .payloadTooLarge
        case .streamFailed:
            .badRequest
        case .invalidEncoding:
            .badRequest
        }
    }

    public var reason: String {
        switch self {
        case .alreadyConsumed:
            "Request body already consumed"
        case .tooLarge:
            "Request body too large"
        case .streamFailed:
            "Request body stream failed"
        case .invalidEncoding:
            "Invalid UTF-8 body"
        }
    }
}

private actor BodyStorage {
    enum Source: Sendable {
        case buffered([UInt8])
        case stream(BodyStreamStorage)
    }

    private var source: Source?

    init(source: Source) {
        self.source = source
    }

    func consume() throws -> BodyConsumer {
        guard let source else {
            throw BodyError.alreadyConsumed
        }

        self.source = nil

        switch source {
        case .buffered(let bytes):
            return BodyConsumer(buffered: bytes.isEmpty ? [] : [ByteChunk(bytes)])
        case .stream(let stream):
            return BodyConsumer(stream: stream)
        }
    }
}

private struct BodyConsumer: Sendable {
    private var buffered: [ByteChunk]?
    private var bufferedIndex = 0
    private let stream: BodyStreamStorage?

    init(buffered: [ByteChunk]) {
        self.buffered = buffered
        self.stream = nil
    }

    init(stream: BodyStreamStorage) {
        self.buffered = nil
        self.stream = stream
    }

    mutating func next() async throws -> ByteChunk? {
        if let buffered {
            guard bufferedIndex < buffered.count else {
                return nil
            }

            let chunk = buffered[bufferedIndex]
            bufferedIndex += 1
            return chunk
        }

        return try await stream?.next()
    }
}

private actor BodyStreamStorage {
    private let bufferLimit: ByteCount
    private var buffer: [ByteChunk] = []
    private var bufferedBytes = 0
    private var isFinished = false
    private var isFailed = false
    private var isCancelled = false
    private var consumerContinuation: CheckedContinuation<ByteChunk?, Error>?
    private var producerContinuations: [CheckedContinuation<Bool, Never>] = []

    init(bufferLimit: ByteCount) {
        self.bufferLimit = bufferLimit
    }

    func write(_ chunk: ByteChunk) async -> Bool {
        guard !isTerminal else {
            return false
        }

        while !hasCapacity(for: chunk), !isTerminal {
            let shouldContinue = await waitForCapacity()
            guard shouldContinue else {
                return false
            }
        }

        guard !isTerminal else {
            return false
        }

        if let consumerContinuation, buffer.isEmpty {
            self.consumerContinuation = nil
            consumerContinuation.resume(returning: chunk)
            return true
        }

        buffer.append(chunk)
        bufferedBytes += chunk.count
        return true
    }

    func finish() {
        guard !isTerminal else {
            return
        }

        isFinished = true
        resumeWaitingProducers(shouldContinue: false)

        if buffer.isEmpty, let consumerContinuation {
            self.consumerContinuation = nil
            consumerContinuation.resume(returning: nil)
        }
    }

    func fail() {
        guard !isTerminal else {
            return
        }

        isFailed = true
        buffer.removeAll(keepingCapacity: false)
        bufferedBytes = 0
        resumeWaitingProducers(shouldContinue: false)

        if let consumerContinuation {
            self.consumerContinuation = nil
            consumerContinuation.resume(throwing: BodyError.streamFailed)
        }
    }

    func cancel() {
        guard !isTerminal else {
            return
        }

        isCancelled = true
        buffer.removeAll(keepingCapacity: false)
        bufferedBytes = 0
        resumeWaitingProducers(shouldContinue: false)

        if let consumerContinuation {
            self.consumerContinuation = nil
            consumerContinuation.resume(returning: nil)
        }
    }

    func next() async throws -> ByteChunk? {
        if !buffer.isEmpty {
            let chunk = buffer.removeFirst()
            bufferedBytes -= chunk.count
            resumeWaitingProducersIfPossible()
            return chunk
        }

        if isFailed {
            throw BodyError.streamFailed
        }

        if isFinished || isCancelled {
            return nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            precondition(consumerContinuation == nil, "RequestBody stream cannot have multiple active consumers")
            consumerContinuation = continuation
        }
    }

    private var isTerminal: Bool {
        isFinished || isFailed || isCancelled
    }

    private func hasCapacity(for chunk: ByteChunk) -> Bool {
        buffer.isEmpty || bufferedBytes + chunk.count <= bufferLimit.bytes
    }

    private func waitForCapacity() async -> Bool {
        await withCheckedContinuation { continuation in
            producerContinuations.append(continuation)
        }
    }

    private func resumeWaitingProducersIfPossible() {
        guard buffer.isEmpty || bufferedBytes < bufferLimit.bytes else {
            return
        }

        resumeWaitingProducers(shouldContinue: true)
    }

    private func resumeWaitingProducers(shouldContinue: Bool) {
        let continuations = producerContinuations
        producerContinuations.removeAll(keepingCapacity: true)

        for continuation in continuations {
            continuation.resume(returning: shouldContinue)
        }
    }
}

private enum UTF8Validator {
    static func isValid(_ bytes: [UInt8]) -> Bool {
        var index = 0

        while index < bytes.count {
            let first = bytes[index]

            if first <= 0x7F {
                index += 1
                continue
            }

            if first >= 0xC2, first <= 0xDF {
                guard hasContinuation(bytes, at: index + 1) else {
                    return false
                }
                index += 2
                continue
            }

            if first == 0xE0 {
                guard hasByte(bytes, at: index + 1, in: 0xA0...0xBF),
                      hasContinuation(bytes, at: index + 2) else {
                    return false
                }
                index += 3
                continue
            }

            if (0xE1...0xEC).contains(first) || (0xEE...0xEF).contains(first) {
                guard hasContinuation(bytes, at: index + 1),
                      hasContinuation(bytes, at: index + 2) else {
                    return false
                }
                index += 3
                continue
            }

            if first == 0xED {
                guard hasByte(bytes, at: index + 1, in: 0x80...0x9F),
                      hasContinuation(bytes, at: index + 2) else {
                    return false
                }
                index += 3
                continue
            }

            if first == 0xF0 {
                guard hasByte(bytes, at: index + 1, in: 0x90...0xBF),
                      hasContinuation(bytes, at: index + 2),
                      hasContinuation(bytes, at: index + 3) else {
                    return false
                }
                index += 4
                continue
            }

            if (0xF1...0xF3).contains(first) {
                guard hasContinuation(bytes, at: index + 1),
                      hasContinuation(bytes, at: index + 2),
                      hasContinuation(bytes, at: index + 3) else {
                    return false
                }
                index += 4
                continue
            }

            if first == 0xF4 {
                guard hasByte(bytes, at: index + 1, in: 0x80...0x8F),
                      hasContinuation(bytes, at: index + 2),
                      hasContinuation(bytes, at: index + 3) else {
                    return false
                }
                index += 4
                continue
            }

            return false
        }

        return true
    }

    private static func hasContinuation(_ bytes: [UInt8], at index: Int) -> Bool {
        hasByte(bytes, at: index, in: 0x80...0xBF)
    }

    private static func hasByte(_ bytes: [UInt8], at index: Int, in range: ClosedRange<UInt8>) -> Bool {
        guard index < bytes.count else {
            return false
        }

        return range.contains(bytes[index])
    }
}
