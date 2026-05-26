import Daylily

@DaylilyServer
struct MacroSmoke {
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
