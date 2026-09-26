import DaylilyCore
import DaylilyOpenAPITransport
import DaylilyServiceLifecycle
import Foundation
import Logging
import OpenAPIRuntime
import OpenAPIURLSession
import ServiceLifecycle
import OldAPI
import NewAPI
import BreakingAPI

private struct NewHandler: NewAPI.APIProtocol {
    func getGreeting(_ input: NewAPI.Operations.getGreeting.Input) async throws -> NewAPI.Operations.getGreeting.Output {
        .ok(.init(body: .json(.init(labels: [.daylily], message: "Hello, \(input.path.name)!", serverVersion: "2"))))
    }
    func echo(_ input: NewAPI.Operations.echo.Input) async throws -> NewAPI.Operations.echo.Output {
        switch input.body {
        case .json(let value):
            return .ok(.init(body: .json(.init(labels: [.daylily], message: value.message, serverVersion: "2"))))
        }
    }
}

private struct BreakingHandler: BreakingAPI.APIProtocol {
    func getGreeting(_ input: BreakingAPI.Operations.getGreeting.Input) async throws -> BreakingAPI.Operations.getGreeting.Output {
        .ok(.init(body: .json(.init(labels: [.daylily], message: "Hello, \(input.path.name)!", serverVersion: "2"))))
    }
    func echo(_ input: BreakingAPI.Operations.echo.Input) async throws -> BreakingAPI.Operations.echo.Output {
        switch input.body {
        case .json(let value):
            return .ok(.init(body: .json(.init(labels: [.daylily], message: value.message, serverVersion: value.tenant))))
        }
    }
}

private enum RegressionFailure: Error { case mismatch, oldClientUnexpectedlyAccepted, unexpectedStatus(Int) }

private struct Verify: Service {
    let ready: AsyncStream<Void>
    let baseURL: URL
    func run() async throws {
        var readyIterator = ready.makeAsyncIterator()
        guard await readyIterator.next() != nil else { throw CancellationError() }
        let transport = URLSessionTransport()
        let old = OldAPI.Client(serverURL: baseURL.appendingPathComponent("compatible"), transport: transport)
        let oldGreeting = try await old.getGreeting(path: .init(name: "old"))
        guard try oldGreeting.ok.body.json.message == "Hello, old!" else { throw RegressionFailure.mismatch }
        let oldEcho = try await old.echo(body: .json(.init(message: "old client")))
        guard try oldEcho.ok.body.json.message == "old client" else { throw RegressionFailure.mismatch }
        print("PASS: old generated client -> compatible new server (GET and POST)")
        let new = NewAPI.Client(serverURL: baseURL.appendingPathComponent("compatible"), transport: transport)
        let newEcho = try await new.echo(body: .json(.init(message: "new client", traceID: "trial")))
        let value = try newEcho.ok.body.json
        guard value.message == "new client", value.serverVersion == "2", value.labels == [.daylily] else { throw RegressionFailure.mismatch }
        print("PASS: new generated client -> compatible new server (optional request and required response addition)")
        let oldAgainstBreaking = OldAPI.Client(serverURL: baseURL.appendingPathComponent("breaking"), transport: transport)
        let rejected = try await oldAgainstBreaking.echo(body: .json(.init(message: "missing tenant")))
        switch rejected {
        case .ok: throw RegressionFailure.oldClientUnexpectedlyAccepted
        case .undocumented(let status, _):
            guard status == 400 else { throw RegressionFailure.unexpectedStatus(status) }
        }
        print("PASS: old generated client rejected with HTTP 400 by newly required request field")
        let breaking = BreakingAPI.Client(serverURL: baseURL.appendingPathComponent("breaking"), transport: transport)
        let accepted = try await breaking.echo(body: .json(.init(message: "new contract", tenant: "tenant-1")))
        guard try accepted.ok.body.json.serverVersion == "tenant-1" else { throw RegressionFailure.mismatch }
        print("PASS: client generated from breaking contract succeeds when new required field is supplied")
    }
}

@main struct ContractRegression {
    static func main() async throws {
        let port = Int(ProcessInfo.processInfo.environment["CONTRACT_PORT"] ?? "18085")!
        let transport = DaylilyOpenAPITransport()
        try NewHandler().registerHandlers(on: transport, serverURL: URL(string: "/compatible")!, middlewares: [ErrorHandlingMiddleware()])
        try BreakingHandler().registerHandlers(on: transport, serverURL: URL(string: "/breaking")!, middlewares: [ErrorHandlingMiddleware()])
        let (ready, continuation) = AsyncStream.makeStream(of: Void.self)
        defer { continuation.finish() }
        let app = transport.application().started { continuation.yield() }
        let group = ServiceGroup(configuration: .init(services: [
            .init(service: app.serviceLifecycleService(configuration: .init(host: "127.0.0.1", port: port, gracefulShutdownSignals: false))),
            .init(service: Verify(ready: ready, baseURL: URL(string: "http://127.0.0.1:\(port)")!), successTerminationBehavior: .gracefullyShutdownGroup),
        ], logger: Logger(label: "contract.regression")))
        try await group.run()
        print("Daylily old/new generated client contract regression passed.")
    }
}
