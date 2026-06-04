import Daylily

@DaylilyServer
struct MacroSmoke {
    func configureDependencies(_ dependencies: inout Dependencies) {
        dependencies.register(MacroGreetingService(prefix: "Macro dependency"), for: MacroDependencies.greeting)
        dependencies.register("root", for: MacroDependencies.label)
    }

    @GET("/macro/hello")
    func hello() -> String {
        "Daylily macros ship."
    }

    @GET("/macro/users/:id")
    func user(req: Request) -> String {
        "Macro user \(req.parameters.id ?? "unknown")"
    }

    @GET("/macro/typed-users/:id")
    func typedUser(@Path id: Int) -> String {
        "Macro typed user \(id)"
    }

    @GET("/macro/accounts/:id")
    func account(@Path("id") accountID: Int) -> String {
        "Macro account \(accountID)"
    }

    @GET("/macro/request-users/:id")
    func requestUser(req: Request, @Path id: Int) -> String {
        "Macro request user \(req.path):\(id)"
    }

    @GET("/macro/search")
    func search(
        @Query term: String,
        @Query("page") pageNumber: Int,
        @Header("x-daylily") token: String
    ) -> String {
        "Macro search \(term):\(pageNumber):\(token)"
    }

    @GET("/macro/dependency/:id")
    func dependency(
        @Path id: Int,
        @Dependency(MacroDependencies.greeting) greeting: any MacroGreetingServing,
        @Dependency(MacroDependencies.label) label: String
    ) -> String {
        "\(label):\(greeting.message(for: id))"
    }

    @POST("/macro/echo")
    func echo(req: Request) async throws -> String {
        try await req.body.string(upTo: .kilobytes(64))
    }

    @GET("/macro/json")
    func json() -> JSON<MacroJSONPayload> {
        JSON(MacroJSONPayload(status: "ok"))
    }

    @POST("/macro/json/echo")
    func jsonEcho(@JSONBody input: MacroEchoPayload) -> JSON<MacroEchoResponse> {
        JSON(MacroEchoResponse(echo: input.message))
    }

    @POST("/macro/body/echo")
    func bodyEcho(@Body input: MacroEchoPayload) -> JSON<MacroEchoResponse> {
        JSON(MacroEchoResponse(echo: input.message))
    }

    @PUT("/macro/users/:id")
    func updateUser(@Path id: Int, req: Request) async throws -> String {
        "Macro updated user \(id):\(try await req.body.string(upTo: .kilobytes(64)))"
    }

    @PATCH("/macro/users/:id")
    func patchUser(@Path id: Int, req: Request) async throws -> String {
        "Macro patched user \(id):\(try await req.body.string(upTo: .kilobytes(64)))"
    }

    @DELETE("/macro/users/:id")
    func deleteUser(@Path id: Int) -> Status {
        .noContent
    }

    @HEAD("/macro/health")
    func headHealth() -> Status {
        .ok
    }

    @OPTIONS("/macro/health")
    func optionsHealth() -> Status {
        .noContent
    }

    @GROUP("/macro/api")
    struct API {
        @GET("/health")
        func health() -> String {
            "Macro group ok."
        }

        @GET("/users/:id")
        func user(req: Request) -> String {
            "Macro group user \(req.parameters.id ?? "unknown")"
        }

        @GET("/typed-users/:id")
        func typedUser(@Path id: Int) -> String {
            "Macro group typed user \(id)"
        }

        @GET("/search")
        func search(
            @Query term: String,
            @Header("x-daylily") token: String
        ) -> String {
            "Macro group search \(term):\(token)"
        }

        @GET("/dependency/:id")
        func dependency(
            @Path id: Int,
            @Dependency(MacroDependencies.greeting) greeting: any MacroGreetingServing
        ) -> String {
            greeting.message(for: id)
        }

        @POST("/echo")
        func echo(req: Request) async throws -> String {
            try await req.body.string(upTo: .kilobytes(64))
        }

        @GET("/json")
        func json() -> JSON<MacroJSONPayload> {
            JSON(MacroJSONPayload(status: "ok"))
        }

        @POST("/json/echo")
        func jsonEcho(@JSONBody input: MacroEchoPayload) -> JSON<MacroEchoResponse> {
            JSON(MacroEchoResponse(echo: input.message))
        }

        @POST("/body/echo")
        func bodyEcho(@Body input: MacroEchoPayload) -> JSON<MacroEchoResponse> {
            JSON(MacroEchoResponse(echo: input.message))
        }

        @PUT("/users/:id")
        func updateUser(@Path id: Int, req: Request) async throws -> String {
            "Macro group updated user \(id):\(try await req.body.string(upTo: .kilobytes(64)))"
        }

        @PATCH("/users/:id")
        func patchUser(@Path id: Int, req: Request) async throws -> String {
            "Macro group patched user \(id):\(try await req.body.string(upTo: .kilobytes(64)))"
        }

        @DELETE("/users/:id")
        func deleteUser(@Path id: Int) -> Status {
            .noContent
        }

        @HEAD("/health")
        func headHealth() -> Status {
            .ok
        }

        @OPTIONS("/health")
        func optionsHealth() -> Status {
            .noContent
        }
    }
}

struct MacroJSONPayload: Codable, Sendable {
    let status: String
}

struct MacroEchoPayload: Codable, Sendable {
    let message: String
}

struct MacroEchoResponse: Codable, Sendable {
    let echo: String
}

enum MacroDependencies {
    static let greeting = DependencyKey<any MacroGreetingServing>("macro.greeting")
    static let label = DependencyKey<String>("macro.label")
}

protocol MacroGreetingServing: Sendable {
    func message(for id: Int) -> String
}

struct MacroGreetingService: MacroGreetingServing {
    let prefix: String

    func message(for id: Int) -> String {
        "\(prefix) \(id)"
    }
}
