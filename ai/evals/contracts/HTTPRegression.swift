import DaylilyCore
import DaylilyOpenAPITransport
import DaylilyServiceLifecycle
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Logging
import OpenAPIRuntime
import OpenAPIURLSession
import ServiceLifecycle
import OldAPI
import NewAPI
import BreakingAPI
import NullableOldAPI
import NullableNewAPI
import NullableBreakingAPI

private struct NullableHandler: NullableNewAPI.APIProtocol {
    func notes(_ input: NullableNewAPI.Operations.notes.Input) async throws -> NullableNewAPI.Operations.notes.Output {
        switch input.body {
        case .json(let value):
            return .ok(.init(body: .json(.init(notes: value.notes.map { $0 ?? "<null>" }))))
        }
    }
}

private struct NullableBreakingHandler: NullableBreakingAPI.APIProtocol {
    func notes(_ input: NullableBreakingAPI.Operations.notes.Input) async throws -> NullableBreakingAPI.Operations.notes.Output {
        .ok(.init(body: .json(.init(notes: [nil]))))
    }
}

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

        let nullableOld = NullableOldAPI.Client(serverURL: baseURL.appendingPathComponent("nullable"), transport: transport)
        let nullableResult = try await nullableOld.notes(body: .json(.init(notes: ["old", nil])))
        guard try nullableResult.ok.body.json.notes == ["old", "<null>"] else { throw RegressionFailure.mismatch }
        print("PASS: old generated nullable client transmits explicit array null")
        let nullableNew = NullableNewAPI.Client(serverURL: baseURL.appendingPathComponent("nullable"), transport: transport)
        let newNullableResult = try await nullableNew.notes(body: .json(.init(note: "memo", notes: [nil, "new"], tag: "tag")))
        guard try newNullableResult.ok.body.json.notes == ["<null>", "new"] else { throw RegressionFailure.mismatch }
        print("PASS: new generated nullable client -> compatible new server")

        // Swift Codable optionals collapse missing and null properties. Check both wire
        // forms directly; required/non-null `notes` remains a separate schema guarantee.
        for (body, status) in [
            (#"{"notes":[null]}"#, 200),
            (#"{"notes":[null],"note":null,"tag":null}"#, 200),
            (#"{"notes":["value"],"note":"memo"}"#, 200),
            (#"{"note":null}"#, 400),
            (#"{"notes":null}"#, 400),
        ] {
            var request = URLRequest(url: baseURL.appendingPathComponent("nullable/notes"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "content-type")
            request.httpBody = Data(body.utf8)
            let (_, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == status else { throw RegressionFailure.mismatch }
        }
        print("PASS: absent/null/value optional properties accepted; absent/null required non-null array rejected")

        let oldNullableAgainstBreaking = NullableOldAPI.Client(serverURL: baseURL.appendingPathComponent("nullable-breaking"), transport: transport)
        let nullRejected = try await oldNullableAgainstBreaking.notes(body: .json(.init(notes: [nil])))
        switch nullRejected {
        case .ok: throw RegressionFailure.oldClientUnexpectedlyAccepted
        case .undocumented(let status, _):
            guard status == 400 else { throw RegressionFailure.unexpectedStatus(status) }
        }
        print("PASS: old generated client's explicit null rejected with HTTP 400 after request nullability removal")
        var responseRejected = false
        do {
            _ = try await oldNullableAgainstBreaking.notes(body: .json(.init(notes: ["valid request"])))
        } catch let error as ClientError {
            guard error.response?.status.code == 200,
                  error.underlyingError is DecodingError else { throw error }
            responseRejected = true
        }
        guard responseRejected else { throw RegressionFailure.oldClientUnexpectedlyAccepted }
        print("PASS: old generated client rejects explicit null after response nullability expansion")
        let breakingNullable = NullableBreakingAPI.Client(serverURL: baseURL.appendingPathComponent("nullable-breaking"), transport: transport)
        let acceptedNull = try await breakingNullable.notes(body: .json(.init(notes: ["new contract"])))
        guard try acceptedNull.ok.body.json.notes == [nil] else { throw RegressionFailure.mismatch }
        print("PASS: client generated from nullable breaking contract accepts its explicit null response")
    }
}

@main struct ContractRegression {
    static func main() async throws {
        let port = Int(ProcessInfo.processInfo.environment["CONTRACT_PORT"] ?? "18085")!
        let transport = DaylilyOpenAPITransport()
        try NewHandler().registerHandlers(on: transport, serverURL: URL(string: "/compatible")!, middlewares: [ErrorHandlingMiddleware()])
        try BreakingHandler().registerHandlers(on: transport, serverURL: URL(string: "/breaking")!, middlewares: [ErrorHandlingMiddleware()])
        try NullableHandler().registerHandlers(on: transport, serverURL: URL(string: "/nullable")!, middlewares: [ErrorHandlingMiddleware()])
        try NullableBreakingHandler().registerHandlers(on: transport, serverURL: URL(string: "/nullable-breaking")!, middlewares: [ErrorHandlingMiddleware()])
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
