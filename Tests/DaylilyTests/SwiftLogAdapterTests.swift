import Daylily
import DaylilySwiftLog
import Foundation
import Logging
import Testing

@Test("SwiftLog sink records request logs without global bootstrap")
func swiftLogSinkRecordsRequestLogsWithoutGlobalBootstrap() async throws {
    let store = RecordingLogStore()
    var logger = Logger(label: "daylily-test") { label in
        RecordingLogHandler(label: label, store: store)
    }
    logger[metadataKey: "service"] = "commerce"

    let sink = SwiftLogRequestLogSink(logger: logger)
    await sink.record(
        RequestLog(
            method: .get,
            path: "/products",
            status: .ok,
            requestID: "dl_request",
            correlationID: "external_request",
            durationNanoseconds: 42,
            errorReason: nil
        )
    )

    let entries = store.snapshot()
    let entry = try #require(entries.first)

    #expect(entries.count == 1)
    #expect(entry.label == "daylily-test")
    #expect(entry.level == .info)
    #expect(entry.message == "GET /products -> 200")
    #expect(metadataString(entry.metadata, "service") == "commerce")
    #expect(metadataString(entry.metadata, "daylily.http.method") == "GET")
    #expect(metadataString(entry.metadata, "daylily.http.path") == "/products")
    #expect(metadataString(entry.metadata, "daylily.http.status_code") == "200")
    #expect(metadataString(entry.metadata, "daylily.request_id") == "dl_request")
    #expect(metadataString(entry.metadata, "daylily.correlation_id") == "external_request")
    #expect(metadataString(entry.metadata, "daylily.duration_ns") == "42")
    #expect(entry.metadata["daylily.error.reason"] == nil)
}

@Test("SwiftLog sink maps status families to default levels")
func swiftLogSinkMapsStatusFamiliesToDefaultLevels() async throws {
    let store = RecordingLogStore()
    let logger = Logger(label: "daylily-levels") { label in
        RecordingLogHandler(label: label, store: store)
    }
    let sink = SwiftLogRequestLogSink(logger: logger)

    await sink.record(RequestLog(method: .get, path: "/ok", status: .ok))
    await sink.record(RequestLog(method: .get, path: "/missing", status: .notFound))
    await sink.record(RequestLog(method: .get, path: "/error", status: .internalServerError))

    let levels = store.snapshot().map(\.level)

    #expect(levels == [.info, .warning, .error])
}

@Test("SwiftLog sink supports custom level and metadata strategies")
func swiftLogSinkSupportsCustomStrategies() async throws {
    let store = RecordingLogStore()
    let logger = Logger(label: "daylily-custom") { label in
        RecordingLogHandler(label: label, store: store)
    }
    let sink = SwiftLogRequestLogSink(
        logger: logger,
        level: .constant(.debug),
        metadata: SwiftLogRequestLogMetadataStrategy { log in
            [
                "custom.status": "\(log.status.code)",
            ]
        }
    )

    await sink.record(RequestLog(method: .delete, path: "/products/1", status: .notFound))

    let entry = try #require(store.snapshot().first)

    #expect(entry.level == .debug)
    #expect(metadataString(entry.metadata, "custom.status") == "404")
    #expect(entry.metadata["daylily.http.method"] == nil)
}

private struct RecordedLog {
    var label: String
    var level: Logger.Level
    var message: String
    var metadata: Logger.Metadata
}

private final class RecordingLogStore: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [RecordedLog] = []

    func record(_ entry: RecordedLog) {
        lock.lock()
        defer { lock.unlock() }
        entries.append(entry)
    }

    func snapshot() -> [RecordedLog] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }
}

private struct RecordingLogHandler: LogHandler {
    let label: String
    let store: RecordingLogStore
    var metadata: Logger.Metadata = [:]
    var logLevel: Logger.Level = .trace

    subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            metadata[metadataKey]
        }
        set {
            metadata[metadataKey] = newValue
        }
    }

    func log(event: LogEvent) {
        var mergedMetadata = self.metadata
        if let metadata = event.metadata {
            for (key, value) in metadata {
                mergedMetadata[key] = value
            }
        }

        store.record(
            RecordedLog(
                label: label,
                level: event.level,
                message: "\(event.message)",
                metadata: mergedMetadata
            )
        )
    }
}

private func metadataString(_ metadata: Logger.Metadata, _ key: String) -> String? {
    metadata[key].map { "\($0)" }
}
