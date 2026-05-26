import AppCore

@main
struct App {
    static func main() async throws {
        if CommandLine.arguments.contains("--check") {
            try await runCommerceChecks()
            return
        }

        try await makeApplication().run()
    }
}
