import TrialApp
import DaylilyCore
import DaylilyOpenAPI
import DaylilyTesting
import Foundation
import Testing

@Suite struct ReplaceDependencyAcceptance {
    private struct TestGreeting: GreetingProvider {
        func greet(_ name: String) -> String { "Test provider received: \(name)" }
    }

    @Test func compositionRootCanSwapProtocolImplementations() async throws {
        let formal = try await TestClient(ReplaceDependency.application()).get("/greetings/Ada")
        try formal.requireBody("Welcome, Ada.")
        let casual = try await TestClient(ReplaceDependency.application(provider: CasualGreeting())).get("/greetings/Ada")
        try casual.requireBody("Hi, Ada!")
        let test = try await TestClient(ReplaceDependency.application(provider: TestGreeting())).get("/greetings/Grace")
        try test.requireBody("Test provider received: Grace")
    }

    @Test func dependencyReplacementPreservesTheRouteContract() throws {
        let before = ReplaceDependency.application(provider: CasualGreeting()).describeRoutes()
        let after = ReplaceDependency.application(provider: FormalGreeting()).describeRoutes()
        #expect(before == after)
    }
}
