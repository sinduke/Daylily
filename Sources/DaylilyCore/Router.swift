public struct Router: Sendable {
    private let routes: [Route]

    public init(routes: [Route] = []) {
        self.routes = routes
    }

    public func describeRoutes() -> [RouteDescription] {
        routes.map { route in
            RouteDescription(method: route.method, path: route.path, metadata: route.metadata)
        }
    }

    public func respond(to request: Request) async throws -> Response {
        guard let match = match(request) else {
            throw Abort(.notFound)
        }

        return try await match.route.respond(
            to: request.with(parameters: Parameters(match.parameters))
        )
    }

    private func match(_ request: Request) -> RouteMatch? {
        let requestSegments = Self.segments(for: request.path)
        var best: RouteMatch?

        for (index, route) in routes.enumerated() where route.method == request.method {
            guard let candidate = Self.match(
                route: route,
                routeIndex: index,
                requestSegments: requestSegments
            ) else {
                continue
            }

            if best == nil || candidate.isPreferred(over: best!) {
                best = candidate
            }
        }

        return best
    }

    private static func match(
        route: Route,
        routeIndex: Int,
        requestSegments: [String]
    ) -> RouteMatch? {
        let routeSegments = segments(for: route.path)
        var parameters: [String: String] = [:]
        var score = 0
        var requestIndex = 0

        for segment in routeSegments {
            if segment.hasPrefix("*") {
                let name = String(segment.dropFirst())
                if !name.isEmpty {
                    parameters[name] = requestSegments[requestIndex...].joined(separator: "/")
                }
                score += 1
                requestIndex = requestSegments.count
                break
            }

            guard requestIndex < requestSegments.count else {
                return nil
            }

            let requestSegment = requestSegments[requestIndex]

            if segment.hasPrefix(":") {
                let name = String(segment.dropFirst())
                parameters[name] = requestSegment
                score += 2
            } else if segment == requestSegment {
                score += 3
            } else {
                return nil
            }

            requestIndex += 1
        }

        guard requestIndex == requestSegments.count else {
            return nil
        }

        return RouteMatch(
            route: route,
            routeIndex: routeIndex,
            score: score,
            parameters: parameters
        )
    }

    private static func segments(for path: String) -> [String] {
        path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
    }
}

private struct RouteMatch {
    let route: Route
    let routeIndex: Int
    let score: Int
    let parameters: [String: String]

    func isPreferred(over other: RouteMatch) -> Bool {
        if score != other.score {
            return score > other.score
        }
        return routeIndex < other.routeIndex
    }
}
