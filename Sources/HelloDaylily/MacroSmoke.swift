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

    @POST("/macro/echo")
    func echo(req: Request) async throws -> String {
        try await req.body.string(upTo: .kilobytes(64))
    }

    @GET("/macro/json")
    func json() -> JSON<MacroJSONPayload> {
        JSON(MacroJSONPayload(status: "ok"))
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

        @POST("/echo")
        func echo(req: Request) async throws -> String {
            try await req.body.string(upTo: .kilobytes(64))
        }

        @GET("/json")
        func json() -> JSON<MacroJSONPayload> {
            JSON(MacroJSONPayload(status: "ok"))
        }
    }
}

struct MacroJSONPayload: Codable, Sendable {
    let status: String
}
