# JSON API Example

Daylily provides explicit JSON helpers on top of the one-shot `RequestBody` model.

## DTOs

```swift
import Daylily

struct CreateUserInput: Codable, Sendable {
    let name: String
}

struct UserResponse: Codable, Sendable {
    let id: Int
    let name: String
}
```

## Runtime Route

```swift
let app = Application {
    Post("/users") { request in
        let input = try await request.json(CreateUserInput.self)
        return JSON(
            UserResponse(id: 1, name: input.name),
            status: .created
        )
    }
}
```

`request.json(Type.self)` delegates to `request.body.json(Type.self, upTo: .megabytes(1))`. Reading or decoding the body consumes the one-shot request body.

## Macro Route

The preferred macro spelling for typed JSON request bodies is `@Body`:

```swift
@main
@DaylilyServer
struct App {
    @POST("/users")
    func create(@Body input: CreateUserInput) -> JSON<UserResponse> {
        JSON(
            UserResponse(id: 1, name: input.name),
            status: .created
        )
    }
}
```

`@JSONBody` remains as a compatibility alias spelling and lowers the same way.

## Try It Against HelloDaylily

The bundled example server includes JSON routes:

```sh
swift run
```

In another terminal:

```sh
curl http://127.0.0.1:8080/json/health
curl -X POST \
  -H 'content-type: application/json' \
  --data '{"message":"hi"}' \
  http://127.0.0.1:8080/json/echo
```

## OpenAPI Metadata

Runtime routes can carry explicit metadata:

```swift
Post("/users") {
    Status.created
}
.describe(
    summary: "Create user",
    tags: ["Users"],
    requestBody: .json("CreateUserInput"),
    responses: [
        .response(.created, contentType: "application/json", type: "UserResponse"),
    ]
)
```

Macro typed inputs lower into the same metadata model, so the runtime remains the source of truth.
