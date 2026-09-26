public struct Application: Sendable {
    private let router: Router
    private let middlewares: [AnyMiddleware]
    private let lifecycleHooks: [LifecyclePhase: [LifecycleOperation]]
    private let dependencies: Dependencies

    public init(@RouteBuilder routes: () -> [Route]) {
        self.init(dependencies: { _ in }, routes: routes)
    }

    public init(
        dependencies configureDependencies: @Sendable (inout Dependencies) -> Void = { _ in },
        @RouteBuilder routes: () -> [Route]
    ) {
        var dependencies = Dependencies()
        configureDependencies(&dependencies)
        self.init(routes: routes(), dependencies: dependencies)
    }

    public init(routes: [Route]) {
        self.init(routes: routes, dependencies: Dependencies())
    }

    public init(routes: [Route], dependencies: Dependencies) {
        self.router = Router(routes: routes)
        self.middlewares = []
        self.lifecycleHooks = [:]
        self.dependencies = dependencies
    }

    public init(routes: Routes) {
        self.init(routes: routes.resolvedRoutes())
    }

    private init(
        router: Router,
        middlewares: [AnyMiddleware],
        lifecycleHooks: [LifecyclePhase: [LifecycleOperation]],
        dependencies: Dependencies
    ) {
        self.router = router
        self.middlewares = middlewares
        self.lifecycleHooks = lifecycleHooks
        self.dependencies = dependencies
    }

    public func middleware<M: Middleware>(_ middleware: M) -> Application {
        var middlewares = self.middlewares
        middlewares.append(AnyMiddleware(middleware))
        return Application(
            router: router,
            middlewares: middlewares,
            lifecycleHooks: lifecycleHooks,
            dependencies: dependencies
        )
    }

    public func lifecycle(
        _ phase: LifecyclePhase,
        _ operation: @escaping LifecycleOperation
    ) -> Application {
        var lifecycleHooks = self.lifecycleHooks
        lifecycleHooks[phase, default: []].append(operation)
        return Application(
            router: router,
            middlewares: middlewares,
            lifecycleHooks: lifecycleHooks,
            dependencies: dependencies
        )
    }

    public func configure(_ operation: @escaping LifecycleOperation) -> Application {
        lifecycle(.configure, operation)
    }

    public func boot(_ operation: @escaping LifecycleOperation) -> Application {
        lifecycle(.boot, operation)
    }

    public func started(_ operation: @escaping LifecycleOperation) -> Application {
        lifecycle(.started, operation)
    }

    public func shutdown(_ operation: @escaping LifecycleOperation) -> Application {
        lifecycle(.shutdown, operation)
    }

    public func cleanup(_ operation: @escaping LifecycleOperation) -> Application {
        lifecycle(.cleanup, operation)
    }

    public func runLifecycle(_ phase: LifecyclePhase) async throws {
        if phase == .shutdown || phase == .cleanup {
            let failures = await collectLifecycleFailures(phase)
            if failures.count == 1 { throw failures[0].error }
            if !failures.isEmpty { throw LifecycleRunError(primaryError: nil, failures: failures) }
            return
        }
        for operation in lifecycleHooks[phase] ?? [] {
            try await operation()
        }
    }

    /// Common execution path for transport and ecosystem adapters.
    @_spi(Lifecycle)
    public func runWithLifecycle(
        _ serve: @Sendable (@escaping LifecycleOperation) async throws -> Void
    ) async throws {
        var primaryError: (any Error)?
        var enteredBoot = false
        do {
            try Task.checkCancellation()
            try await runLifecycle(.configure)
            try Task.checkCancellation()
            enteredBoot = true
            try await runLifecycle(.boot)
            try Task.checkCancellation()
            try await serve { try await runLifecycle(.started) }
        } catch {
            primaryError = error
        }

        // This task is deliberately independent of caller cancellation. We await it
        // before returning so asynchronous cleanup can finish after server cancellation.
        let shouldShutdown = enteredBoot
        let teardown = Task {
            var failures: [LifecycleFailure] = []
            if shouldShutdown { failures += await collectLifecycleFailures(.shutdown) }
            failures += await collectLifecycleFailures(.cleanup)
            return failures
        }
        let failures = await teardown.value
        if let primaryError {
            if failures.isEmpty { throw primaryError }
            throw LifecycleRunError(primaryError: primaryError, failures: failures)
        }
        if failures.count == 1 { throw failures[0].error }
        if !failures.isEmpty { throw LifecycleRunError(primaryError: nil, failures: failures) }
    }

    private func collectLifecycleFailures(_ phase: LifecyclePhase) async -> [LifecycleFailure] {
        var failures: [LifecycleFailure] = []
        for (index, operation) in (lifecycleHooks[phase] ?? []).enumerated() {
            do { try await operation() }
            catch { failures.append(LifecycleFailure(phase: phase, hookIndex: index, error: error)) }
        }
        return failures
    }

    public func describeRoutes() -> [RouteDescription] {
        router.describeRoutes()
    }

    public func respond(to request: Request) async -> Response {
        let request = request.with(dependencies: dependencies)
        let terminal = Handler { request in
            await Self.render {
                try await router.respond(to: request)
            }
        }
        let pipeline = middlewarePipeline(middlewares: middlewares, terminal: terminal)

        return await Self.render {
            try await pipeline.respond(to: request)
        }
    }

    private static func render(_ operation: @Sendable () async throws -> Response) async -> Response {
        do {
            return try await operation()
        } catch let error as ResponseError {
            return Response.text(error.reason, status: error.status)
        } catch {
            return Response.text("Internal Server Error", status: .internalServerError)
        }
    }
}
