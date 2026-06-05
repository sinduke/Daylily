# Swift HTTP Types

`DaylilyHTTPTypes` is an optional adapter module for projects that already use
Swift HTTP Types at their HTTP boundary.

It is not re-exported by `Daylily`:

```swift
import Daylily
import DaylilyHTTPTypes

let request = Request(
    method: HTTPMethod("PROPFIND")!,
    path: "/items?tag=tea&tag=oolong"
)

let httpRequest = try request.httpTypesRequest()
let roundTripped = Request(httpTypesRequest: httpRequest)
```

The adapter preserves Daylily's HTTP boundary instead of replacing it:

- custom HTTP method tokens are preserved
- repeated headers are preserved
- raw request targets are preserved
- repeated query parameters are preserved
- Swift HTTP Types pseudo fields are preserved on `Request`

Header and status conversions throw when Swift HTTP Types cannot represent the
Daylily value without legalizing it. Silent lossy conversion is intentionally
not allowed at this boundary.

`DaylilyHTTPTypes` does not add a transport and does not consume
`RequestBody`. Body ownership remains explicit: Daylily request bodies are
still one-shot, and response bodies remain Daylily `[UInt8]` values unless an
application chooses a higher-level transport integration.
