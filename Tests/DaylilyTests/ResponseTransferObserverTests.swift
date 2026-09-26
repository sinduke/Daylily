import DaylilyCore
import DaylilyObservability
import DaylilySwiftLog
import Foundation
import Logging
import Testing

@Suite("Response transfer observers")
struct ResponseTransferObserverTests {
    @Test("Collector accepts concurrent terminal events without dropping metadata")
    func concurrentCollector() async {
        let observer = InMemoryResponseTransferObserver()
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<40 {
                group.addTask {
                    await observer.record(ResponseTransferEvent(
                        method: .get, path: "/events", status: .ok,
                        requestID: "request-\(index)", bytesSent: index,
                        durationNanoseconds: UInt64(index), outcome: .completed
                    ))
                }
            }
        }
        let events = await observer.snapshot()
        #expect(events.count == 40)
        #expect(Set(events.compactMap(\.requestID)).count == 40)
        #expect(events.allSatisfy { $0.bytesSent == Int($0.durationNanoseconds) })
    }

    @Test("SwiftLog separates transfer outcome and duration from handler latency")
    func logMetadataAndLevels() async throws {
        let store = TransferLogStore()
        var logger = Logger(label: "application.transfer") { _ in TransferLogHandler(store: store) }
        logger[metadataKey: "application"] = "example"
        let observer = SwiftLogResponseTransferObserver(logger: logger)
        for outcome in [ResponseTransferOutcome.completed, .cancelled, .failed] {
            await observer.record(ResponseTransferEvent(
                method: .get, path: "/stream", status: .ok,
                requestID: "dl_1", correlationID: "external_1",
                bytesSent: 7, durationNanoseconds: 900, outcome: outcome
            ))
        }
        let entries = store.snapshot()
        #expect(entries.map(\.level) == [.info, .notice, .error])
        #expect(entries.map(\.message) == ["Response transfer completed", "Response transfer cancelled", "Response transfer failed"])
        let metadata = try #require(entries.first?.metadata)
        #expect(metadata["application"] == "example")
        #expect(metadata["daylily.http.method"] == "GET")
        #expect(metadata["daylily.http.path"] == "/stream")
        #expect(metadata["daylily.http.status_code"] == "200")
        #expect(metadata["daylily.request_id"] == "dl_1")
        #expect(metadata["daylily.correlation_id"] == "external_1")
        #expect(metadata["daylily.event"] == "response_transfer")
        #expect(metadata["daylily.response.bytes_sent"] == "7")
        #expect(metadata["daylily.response.transfer_duration_ns"] == "900")
        #expect(metadata["daylily.duration_ns"] == nil)
        #expect(entries.last?.metadata["daylily.response.outcome"] == "failed")
    }

    @Test("Protocol errors can be logged without fabricated request metadata")
    func absentRequestMetadata() async throws {
        let store = TransferLogStore()
        let logger = Logger(label: "application.transfer") { _ in TransferLogHandler(store: store) }
        await SwiftLogResponseTransferObserver(logger: logger).record(ResponseTransferEvent(
            status: .badRequest, bytesSent: 0, durationNanoseconds: 12, outcome: .completed
        ))
        let entry = try #require(store.snapshot().first)
        #expect(entry.level == .info) // An error HTTP response may still transfer successfully.
        #expect(entry.metadata["daylily.http.status_code"] == "400")
        #expect(entry.metadata["daylily.http.method"] == nil)
        #expect(entry.metadata["daylily.http.path"] == nil)
        #expect(entry.metadata["daylily.request_id"] == nil)
    }
}

private struct TransferLogEntry: Sendable {
    let level: Logger.Level
    let message: String
    let metadata: Logger.Metadata
}

private final class TransferLogStore: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [TransferLogEntry] = []

    func append(_ entry: TransferLogEntry) {
        lock.lock()
        defer { lock.unlock() }
        entries.append(entry)
    }

    func snapshot() -> [TransferLogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }
}

private struct TransferLogHandler: LogHandler {
    let store: TransferLogStore
    var logLevel: Logger.Level = .trace
    var metadata: Logger.Metadata = [:]

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }

    func log(event: LogEvent) {
        let merged = metadata.merging(event.metadata ?? [:], uniquingKeysWith: { _, new in new })
        store.append(TransferLogEntry(level: event.level, message: "\(event.message)", metadata: merged))
    }
}
