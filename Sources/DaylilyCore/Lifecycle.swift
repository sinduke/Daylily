public typealias LifecycleOperation = @Sendable () async throws -> Void

public enum LifecyclePhase: String, Sendable, CaseIterable {
    case configure
    case boot
    case started
    case shutdown
    case cleanup
}

public struct LifecycleFailure: Sendable {
    public let phase: LifecyclePhase
    public let hookIndex: Int
    public let error: any Error

    public init(phase: LifecyclePhase, hookIndex: Int, error: any Error) {
        self.phase = phase
        self.hookIndex = hookIndex
        self.error = error
    }
}

/// Preserves the original execution error together with every teardown failure.
public struct LifecycleRunError: Error, Sendable {
    public let primaryError: (any Error)?
    public let failures: [LifecycleFailure]

    public init(primaryError: (any Error)?, failures: [LifecycleFailure]) {
        self.primaryError = primaryError
        self.failures = failures
    }
}
