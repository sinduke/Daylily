import AppCore
import Daylily

@main
struct AppMain {
    static func main() async throws {
        if CommandLine.arguments.contains("--check") {
            try await runChecks()
            return
        }

        try await makeApplication().run()
    }

    private static func runChecks() async throws {
        let app = makeApplication()
        let response = await app.respond(to: Request(method: .get, path: "/hello"))

        guard response.status == .ok else {
            throw SmokeFailure("Expected 200 OK, got \(response.status.code)")
        }

        guard response.bodyString == "Daylily minimal app ships." else {
            throw SmokeFailure("Unexpected body: \(response.bodyString)")
        }

        print("Daylily minimal app checks passed.")
    }
}

struct SmokeFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
