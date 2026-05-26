@resultBuilder
public enum RouteBuilder {
    public static func buildExpression(_ expression: Route) -> [Route] {
        [expression]
    }

    public static func buildExpression(_ expression: [Route]) -> [Route] {
        expression
    }

    public static func buildExpression(_ expression: Routes) -> [Route] {
        expression.resolvedRoutes()
    }

    public static func buildBlock(_ components: [Route]...) -> [Route] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [Route]?) -> [Route] {
        component ?? []
    }

    public static func buildEither(first component: [Route]) -> [Route] {
        component
    }

    public static func buildEither(second component: [Route]) -> [Route] {
        component
    }

    public static func buildArray(_ components: [[Route]]) -> [Route] {
        components.flatMap { $0 }
    }
}
