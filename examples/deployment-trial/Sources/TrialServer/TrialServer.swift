import Daylily
import Foundation

private func emit(_ message: String) {
    FileHandle.standardOutput.write(Data((message + "\n").utf8))
}

private struct Health: Codable, Sendable {
    let instance: String
    let status: String
}

private struct TaskInput: Codable, Sendable { let text: String }
private struct TaskOutput: Codable, Sendable { let instance: String; let normalized: String }

private struct MetricsSnapshot: Codable, Sendable {
    let instance: String
    let activeStreams: Int
    let completed: Int
    let cancelled: Int
    let failed: Int
    let bytesSent: Int
}

private actor TrialMetrics: ResponseTransferObserver {
    let instance: String
    private var activeStreams = 0
    private var completed = 0
    private var cancelled = 0
    private var failed = 0
    private var bytesSent = 0

    init(instance: String) { self.instance = instance }
    func beginStream() { activeStreams += 1 }
    func endStream() { activeStreams -= 1 }

    func record(_ event: ResponseTransferEvent) {
        switch event.outcome {
        case .completed: completed += 1
        case .cancelled: cancelled += 1
        case .failed: failed += 1
        }
        bytesSent += event.bytesSent
        emit("TRANSFER instance=\(instance) path=\(event.path ?? "-") outcome=\(event.outcome.rawValue) bytes=\(event.bytesSent) duration_ns=\(event.durationNanoseconds)")
    }

    func snapshot() -> MetricsSnapshot {
        MetricsSnapshot(instance: instance, activeStreams: activeStreams,
                        completed: completed, cancelled: cancelled, failed: failed, bytesSent: bytesSent)
    }
}

@main
struct TrialServer {
    static func main() async throws {
        let environment = ProcessInfo.processInfo.environment
        let instance = environment["TRIAL_INSTANCE"] ?? "local"
        let port = Int(environment["TRIAL_PORT"] ?? "8080") ?? 8080
        let host = environment["TRIAL_HOST"] ?? "127.0.0.1"
        let metrics = TrialMetrics(instance: instance)
        let application = Application {
            Get("/health") { JSON(Health(instance: instance, status: "ok")) }
            Get("/metrics") { JSON(await metrics.snapshot()) }
            Post("/tasks/normalize") { request in
                let input = try await request.json(TaskInput.self, upTo: .kilobytes(16))
                return JSON(TaskOutput(instance: instance, normalized: input.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()))
            }
            Get("/tasks/:id/events") { request in
                let taskID = try request.parameters.require("id", as: String.self)
                let steps = try request.query.get("steps", as: Int.self) ?? 10
                let interval = try request.query.get("interval", as: Int.self) ?? 100
                guard (1...10_000).contains(steps), (10...2_000).contains(interval), taskID.count <= 64 else {
                    throw Abort(.badRequest, reason: "Invalid task parameters")
                }
                return Response.eventStream { writer in
                    await metrics.beginStream()
                    do {
                        for index in 1...steps {
                            try await writer.write(ServerSentEvent(data: "\(taskID):\(index):\(instance)", id: String(index), event: "progress"))
                            if index < steps { try await Task.sleep(for: .milliseconds(interval)) }
                        }
                        await metrics.endStream()
                    } catch {
                        await metrics.endStream()
                        throw error
                    }
                }
            }
            // These diagnostic routes belong only to this localhost deployment trial.
            Get("/slow") { request in
                let delay = try request.query.get("ms", as: Int.self) ?? 500
                guard (0...10_000).contains(delay) else { throw Abort(.badRequest) }
                try await Task.sleep(for: .milliseconds(delay))
                return JSON(Health(instance: instance, status: "completed"))
            }
            Post("/upload") { request in
                let body = try await request.body.collect(upTo: .megabytes(8))
                return String(body.count)
            }
            Get("/burst") { request in
                let chunks = try request.query.get("chunks", as: Int.self) ?? 4_096
                guard (1...16_384).contains(chunks) else { throw Abort(.badRequest) }
                return Response(body: .stream { writer in
                    await metrics.beginStream()
                    do {
                        let bytes = [UInt8](repeating: 120, count: 65_536)
                        for _ in 0..<chunks { try await writer.write(bytes) }
                        await metrics.endStream()
                    } catch {
                        await metrics.endStream()
                        throw error
                    }
                })
            }
            Get("/failure") {
                Response(body: .stream { writer in
                    try await writer.write("started")
                    throw Abort(.internalServerError, reason: "Trial producer failure")
                })
            }
        }
        .shutdown { emit("LIFECYCLE instance=\(instance) shutdown") }
        .cleanup { emit("LIFECYCLE instance=\(instance) cleanup") }

        try await application.run(configuration: ServerConfiguration(
            host: host, port: port,
            requestHeaderTimeout: .seconds(2), uploadIdleTimeout: .seconds(2),
            shutdownGracePeriod: .seconds(2)
        ), responseObserver: metrics)
    }
}
