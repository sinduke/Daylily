public typealias LifecycleOperation = @Sendable () async throws -> Void

public enum LifecyclePhase: String, Sendable, CaseIterable {
    case configure
    case boot
    case started
    case shutdown
    case cleanup
}
