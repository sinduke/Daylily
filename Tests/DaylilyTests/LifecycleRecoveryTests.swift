import Daylily
@_spi(Lifecycle) import DaylilyCore
import DaylilyServiceLifecycle
import Testing

private enum LifecycleTestError: Error, Equatable { case configure, boot, started, shutdown, cleanup }
private actor RecoveryTrace {
    var entries: [String] = []
    func add(_ value: String) { entries.append(value) }
}

@Suite("Lifecycle recovery")
struct LifecycleRecoveryTests {
    @Test("Configure failure runs all cleanup hooks without boot or shutdown")
    func configureFailure() async throws {
        let trace = RecoveryTrace()
        let app = Application { }
            .configure { throw LifecycleTestError.configure }
            .boot { Issue.record("boot must not run") }
            .shutdown { Issue.record("shutdown must not run before boot") }
            .cleanup { await trace.add("cleanup") }
        do {
            try await app.runWithLifecycle { _ in Issue.record("server must not start") }
            Issue.record("Expected configure failure")
        } catch let error as LifecycleTestError { #expect(error == .configure) }
        #expect(await trace.entries == ["cleanup"])
    }

    @Test("Partial boot failure preserves the primary error and all teardown failures")
    func bootFailure() async throws {
        let trace = RecoveryTrace()
        let app = Application { }
            .boot { await trace.add("boot-1") }
            .boot { throw LifecycleTestError.boot }
            .boot { Issue.record("remaining boot hooks must not run") }
            .shutdown { await trace.add("shutdown-1"); throw LifecycleTestError.shutdown }
            .shutdown { await trace.add("shutdown-2") }
            .cleanup { await trace.add("cleanup-1"); throw LifecycleTestError.cleanup }
            .cleanup { await trace.add("cleanup-2") }
        do {
            try await app.runWithLifecycle { _ in Issue.record("server must not start") }
            Issue.record("Expected aggregate failure")
        } catch let error as LifecycleRunError {
            #expect(error.primaryError as? LifecycleTestError == .boot)
            #expect(error.failures.map(\.phase) == [.shutdown, .cleanup])
            #expect(error.failures.map(\.hookIndex) == [0, 0])
        }
        #expect(await trace.entries == ["boot-1", "shutdown-1", "shutdown-2", "cleanup-1", "cleanup-2"])
    }

    @Test("Teardown failure never repeats hooks and direct phases attempt every hook")
    func teardownFailure() async throws {
        let trace = RecoveryTrace()
        let app = Application { }
            .shutdown { await trace.add("shutdown"); throw LifecycleTestError.shutdown }
            .cleanup { await trace.add("cleanup-1"); throw LifecycleTestError.cleanup }
            .cleanup { await trace.add("cleanup-2") }
        do {
            try await app.runWithLifecycle { started in try await started() }
            Issue.record("Expected teardown failure")
        } catch let error as LifecycleRunError {
            #expect(error.primaryError == nil)
            #expect(error.failures.count == 2)
        }
        #expect(await trace.entries == ["shutdown", "cleanup-1", "cleanup-2"])
        do { try await app.runLifecycle(.cleanup) }
        catch let error as LifecycleTestError { #expect(error == .cleanup) }
        #expect(await trace.entries == ["shutdown", "cleanup-1", "cleanup-2", "cleanup-1", "cleanup-2"])
    }

    @Test("Cancellation still permits awaited asynchronous teardown")
    func cancellation() async throws {
        let trace = RecoveryTrace()
        let (events, continuation) = AsyncStream.makeStream(of: Void.self)
        let app = Application { }
            .shutdown { try Task.checkCancellation(); await trace.add("shutdown") }
            .cleanup { try await Task.sleep(for: .milliseconds(1)); await trace.add("cleanup") }
        let task = Task {
            try await app.runWithLifecycle { _ in
                continuation.yield()
                continuation.finish()
                try await Task.sleep(for: .seconds(60))
            }
        }
        for await _ in events { break }
        task.cancel()
        do { try await task.value; Issue.record("Expected cancellation") }
        catch is CancellationError { }
        #expect(await trace.entries == ["shutdown", "cleanup"])
    }

    @Test("Cancellation while configuring never starts boot resources")
    func configureCancellation() async throws {
        let trace = RecoveryTrace()
        let (ready, signal) = AsyncStream.makeStream(of: Void.self)
        let (waiting, hold) = AsyncStream.makeStream(of: Void.self)
        defer { hold.finish() }
        let app = Application { }
            .configure {
                signal.yield()
                signal.finish()
                for await _ in waiting { }
            }
            .boot { Issue.record("Cancelled configure must not start boot") }
            .shutdown { Issue.record("Boot never started") }
            .cleanup { await trace.add("cleanup") }
        let task = Task { try await app.runWithLifecycle { _ in Issue.record("Server must not run") } }
        for await _ in ready { break }
        task.cancel()
        do { try await task.value; Issue.record("Expected cancellation") }
        catch is CancellationError { }
        #expect(await trace.entries == ["cleanup"])
    }

    @Test("Both server entry points recover from started failure", arguments: [false, true])
    func startedFailure(serviceLifecycle: Bool) async throws {
        let trace = RecoveryTrace()
        let app = Application { }
            .started { throw LifecycleTestError.started }
            .shutdown { await trace.add("shutdown") }
            .cleanup { await trace.add("cleanup") }
        let config = ServerConfiguration(port: 0, gracefulShutdownSignals: false)
        do {
            if serviceLifecycle { try await app.serviceLifecycleService(configuration: config).run() }
            else { try await app.run(configuration: config) }
            Issue.record("Expected started failure")
        } catch let error as LifecycleTestError { #expect(error == .started) }
        #expect(await trace.entries == ["shutdown", "cleanup"])
    }
}
