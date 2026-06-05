# Swift OpenAPI Generator Transport

`DaylilyOpenAPITransport` is an optional server transport for projects using
Swift OpenAPI Generator server stubs.

```swift
import Daylily
import DaylilyOpenAPITransport
import Foundation

let transport = DaylilyOpenAPITransport()
let handler = GeneratedAPIHandler()

try handler.registerHandlers(
    on: transport,
    serverURL: URL(string: "/api")!
)

try await transport.application().run()
```

The transport conforms to OpenAPIRuntime `ServerTransport`. Generated handlers
register HTTP operations on the transport, and the transport turns those
registrations into Daylily routes.

Supported path templates:

```text
/pets/{petId} -> /pets/:petId
```

Only whole-segment path parameters are supported today. Mixed segments such as
`/files/{name}.zip` throw during registration instead of silently registering a
route Daylily cannot match correctly.

Request bodies remain one-shot and stream into OpenAPIRuntime `HTTPBody`.
Generated response bodies are buffered into Daylily `Response` under the
transport's `responseBodyBufferLimit` because Daylily does not yet expose
streaming response bodies.
