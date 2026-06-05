import Daylily
import DaylilyServiceLifecycle
import Foundation
import ServiceLifecycleTestKit
import Testing

@Test("ServiceLifecycle default configuration leaves signal handling to ServiceGroup")
func serviceLifecycleDefaultConfigurationLeavesSignalsToServiceGroup() {
    #expect(ServerConfiguration().gracefulShutdownSignals)
    #expect(ServerConfiguration.serviceLifecycleDefault.gracefulShutdownSignals == false)
    #expect(ServerConfiguration.serviceLifecycleDefault.withGracefulShutdownSignals(true).gracefulShutdownSignals)
}

@Test("Daylily ServiceLifecycle service runs and shuts down application lifecycle")
func daylilyServiceLifecycleServiceRunsAndShutsDownApplicationLifecycle() async throws {
    let events = LifecycleEvents()
    let app = Application {
        Get("/service-lifecycle") {
            "ok"
        }
    }
    .configure {
        events.append("configure")
    }
    .boot {
        events.append("boot")
    }
    .started {
        events.append("started")
    }
    .shutdown {
        events.append("shutdown")
    }
    .cleanup {
        events.append("cleanup")
    }

    let service = app.serviceLifecycleService(
        configuration: ServerConfiguration(port: 0, gracefulShutdownSignals: false)
    )

    try await testGracefulShutdown { trigger in
        let serviceTask = Task {
            try await service.run()
        }
        defer {
            serviceTask.cancel()
        }

        try await withTimeout("DaylilyApplicationService started") {
            await events.wait(for: "started")
        }

        trigger.triggerGracefulShutdown()

        try await withTimeout("DaylilyApplicationService shutdown") {
            try await serviceTask.value
        }
    }

    #expect(events.snapshot() == ["configure", "boot", "started", "shutdown", "cleanup"])
}

private final class LifecycleEvents: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [String] = []
    private let stream: AsyncStream<String>
    private let continuation: AsyncStream<String>.Continuation

    init() {
        var continuation: AsyncStream<String>.Continuation!
        self.stream = AsyncStream { continuation = $0 }
        self.continuation = continuation
    }

    func append(_ event: String) {
        lock.lock()
        events.append(event)
        lock.unlock()
        continuation.yield(event)
    }

    func snapshot() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }

    func wait(for event: String) async {
        if snapshot().contains(event) {
            return
        }

        for await emitted in stream {
            if emitted == event {
                return
            }
        }
    }
}

private enum TimeoutError: Error {
    case timedOut(String)
}

private func withTimeout<T: Sendable>(
    _ description: String,
    nanoseconds: UInt64 = 5_000_000_000,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: nanoseconds)
            throw TimeoutError.timedOut(description)
        }

        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
