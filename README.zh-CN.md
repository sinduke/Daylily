<div align="center">

# Daylily

### 现代 AI-first Swift Web 框架

为 Swift Concurrency 时代构建。<br>
同时为人类开发者和 AI agent 设计。

[English](README.md) | [简体中文](README.zh-CN.md)

[Documentation](docs/README.md) •
[快速开始](#快速开始) •
[详细使用教程](#详细使用教程) •
[AI-Native](#ai-native-by-design) •
[架构](#架构) •
[路线图](#路线图)

[![CI](https://github.com/sinduke/Daylily/actions/workflows/ci.yml/badge.svg)](https://github.com/sinduke/Daylily/actions/workflows/ci.yml)
![Swift](https://img.shields.io/badge/Swift-6-orange)
![Platform](https://img.shields.io/badge/platform-macOS%2014%2B%20%7C%20Linux%20CI-blue)
![Concurrency](https://img.shields.io/badge/Concurrency-Native-green)
![OpenAPI](https://img.shields.io/badge/OpenAPI-MVP-8A2BE2)
![Status](https://img.shields.io/badge/status-Experimental-red)

</div>

---

## 为什么 Daylily 存在

服务端 Swift 的底层基础很强。

但很多框架仍然带着 pre-Concurrency 时代的痕迹：

- 应用层代码经常绕不开 EventLoop 心智。
- transport 细节容易漏进用户 API。
- runtime pattern 更像是服务框架内部优化，而不是面向产品开发。
- AI agent 必须从源码里反推架构。
- 宏优先的设计有时会让 runtime 真相变得不够清晰。

Daylily 选择另一条路：

- Swift Concurrency first。
- Runtime-first architecture。
- AI-native development workflow。
- 显式契约优先于隐藏魔法。
- 面向真实产品开发的 DX。

Daylily 一开始刻意保持很小：一个声明式 runtime、一个基于 NIO 的 HTTP/1.1 server，以及一套 AIDEV 契约。AIDEV 的目标是让 AI 不需要先翻源码，也能快速理解、使用、升级和扩展这个项目。

## 十秒 Hello World

```swift
import Daylily

@main
@DaylilyServer
struct App {
    @GET("/hello")
    func hello() -> String {
        "Daylily ships."
    }
}
```

就这样。

## 核心理念

### AI-Native by Design

Daylily 的设计目标之一，是让 AI agent 可以安全理解并扩展项目。

我们不希望 AI 只能从源码里反推架构，而是直接暴露：

- architecture contracts；
- API registries；
- runtime guarantees；
- extension playbooks；
- project maps；
- machine-readable metadata。

AI 是一等开发参与者。

### Runtime First

宏是工具。Runtime 真相更重要。

Daylily 优先考虑：

- 可观察的 runtime state；
- 显式契约；
- 确定性的架构；
- 便于 introspection 的系统。

### Default Path, Not Mandatory Path

Daylily 提供推荐默认路径，但不会要求应用把自己的架构交给框架。

- Runtime DSL 是一等 API，不是宏不够用时的 fallback。
- `@DaylilyServer` 和 route macros 是 runtime routes 上的便利语法。
- `Dependencies` registry 是默认依赖通道，不是强制 DI container。
- 应用可以保留自己的 composition root、捕获自己的 services，或者注册自己的 container。

### Swift Concurrency First

Daylily 围绕现代 Swift 设计：

- `async` / `await`；
- `Sendable`；
- structured concurrency；
- 不泄漏到用户侧 API 的 transport boundary。

## 能力矩阵

| 能力 | 状态 |
| --- | --- |
| Swift Concurrency-native runtime | 已实现 |
| 声明式 route DSL | 已实现 |
| Macro route/group declarations | MVP |
| Typed path/query/header inputs | 已实现 |
| `@Body` typed JSON body input | 已实现 |
| Middleware | 已实现 |
| Streaming request body | 已实现 |
| JSON body/response helpers | 已实现 |
| OpenAPI generation | MVP |
| Observability middleware | MVP |
| Transport-free testing helpers | 已实现 |
| AIDEV AI handoff system | 已实现 |
| Dependencies registry | MVP |
| Macro middleware attributes | Planned |
| Full Swift schema derivation | Planned |

## 架构

```text
Client / SwiftUI / Flutter / API Consumer
        |
        v
Shared DTOs and HTTP contracts
        |
        v
Daylily Runtime
        |
        +--> Route metadata --> OpenAPI
        |
        +--> AIDEV contracts --> AI agents
        |
        v
Transport layer
```

Runtime 仍然是框架真相来源。宏会降级成 runtime routes 和 metadata；OpenAPI 和 AI tooling 读取的是同一套显式契约，而不是从源码里猜。

Daylily 的默认能力都应该是可替换的。当 macro shape 或内置 helper 不适合真实应用时，runtime API 仍然是受支持的正路。

## Benchmarks

Benchmarks 正在准备中。

当前优先级是：

- 可预测架构；
- concurrency correctness；
- developer experience；
- AI collaboration；
- long-term maintainability。

Raw performance benchmarks 会在 runtime 和 beta 文档稳定后发布。

## 生态愿景

Daylily 不是只想成为 routing library，而是在探索 Swift cloud development experience。

潜在生态方向：

- authentication；
- realtime features；
- queues and background jobs；
- deployment tooling；
- AI-assisted architecture workflow；
- fullstack Swift patterns。

## 快速开始

作为 SwiftPM package 使用：

```swift
.package(url: "https://github.com/sinduke/Daylily.git", from: "0.1.0-alpha.1")
```

`main` 分支 README 可能会描述尚未进入 tag 的 API。`Dependencies` registry 目前可从源码 checkout 使用，会进入后续 pre-release tag。

把 product 加到 target 里：

```swift
.product(name: "Daylily", package: "Daylily")
```

本地开发框架或运行示例时，可以继续从源码启动。

在项目根目录执行：

```sh
swift build
swift test
swift run HelloDaylily --check
swift run
```

如果要从一个全新的外部 SwiftPM package 验证 Daylily：

```sh
scripts/consumer-smoke-test.sh --mode path
scripts/consumer-smoke-test.sh --mode release --version 0.1.0-alpha.1
```

如果要从推荐的最小 app 结构开始：

```sh
cp -R templates/minimal-app MyDaylilyApp
cd MyDaylilyApp
swift build
swift test
swift run App --check
```

如果要试第一个真实 API 示例：

```sh
scripts/example-smoke-test.sh --mode path
cd examples/commerce-api
swift run App --check
swift run App
```

Daylily 使用 Swift Testing 作为正式 test target。如果 `swift test` 报 `no such module 'Testing'`，并且 `xcode-select -p` 指向 Command Line Tools，可以显式指定 Xcode developer directory：

```sh
DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer swift test
```

服务监听：

```text
http://127.0.0.1:8080
```

试一下：

```sh
curl http://127.0.0.1:8080/hello
curl http://127.0.0.1:8080/users/42
curl 'http://127.0.0.1:8080/search?term=daylily&page=1'
curl -H 'x-daylily: ships' http://127.0.0.1:8080/headers
curl -X POST --data 'hi' http://127.0.0.1:8080/echo
curl -X PUT --data 'full' http://127.0.0.1:8080/users/42
curl -X PATCH --data 'partial' http://127.0.0.1:8080/users/42
curl -i -X DELETE http://127.0.0.1:8080/users/42
curl -I http://127.0.0.1:8080/health
curl -i -X OPTIONS http://127.0.0.1:8080/health
printf 'abcdef' | curl --http1.1 -H 'Transfer-Encoding: chunked' -H 'Content-Length:' --data-binary @- http://127.0.0.1:8080/upload/count
curl http://127.0.0.1:8080/json/health
curl -X POST -H 'content-type: application/json' --data '{"message":"hi"}' http://127.0.0.1:8080/json/echo
```

## 详细使用教程

README 后半部分就是详细使用教程入口，保留了可以直接复制的示例。

独立 beta docs 也已经可用：

- [Documentation hub](docs/README.md)
- [Quick Start](docs/quickstart.md)
- [Capability Matrix](docs/capability-matrix.md)
- [Release Readiness](docs/release-readiness.md)
- [Commerce API Example](docs/examples/commerce-api.md)
- [Dependencies Usage](docs/examples/dependencies.md)
- [JSON API Example](docs/examples/json-api.md)
- [Middleware Example](docs/examples/middleware.md)
- [Testing Example](docs/examples/testing.md)

README 里的详细章节：

- [当前 API](#当前-api)：runtime routes、typed parameters、JSON、lifecycle 和 server configuration。
- [Dependencies](#dependencies)：app-wide 默认依赖 registry，以及用户自有 service wiring。
- [Runtime Middleware](#runtime-middleware)：application、group、route 三层 middleware，以及 one-shot body 规则。
- [Observability](#observability)：request ID 和 request logging middleware。
- [Route Metadata](#route-metadata)：显式 metadata 和最小 OpenAPI generation。
- [DaylilyTesting](#daylilytesting)：in-memory tests、request builders 和 JSON assertions。
- [Macro API MVP](#macro-api-mvp)：`@DaylilyServer`、route macros、typed inputs 和 macro 限制。
- [AI-Native 开发](#ai-native-开发)：AIDEV contracts、registries、playbooks 和 agent workflow。

## 当前 API

现在已经可用的 runtime API 是这样：

```swift
import Daylily

struct HealthPayload: Codable, Sendable {
    let status: String
}

struct CreateUserInput: Codable, Sendable {
    let name: String
}

struct EchoPayload: Codable, Sendable {
    let message: String
}

struct EchoResponse: Codable, Sendable {
    let echo: String
}

@main
struct HelloDaylily {
    static func main() async throws {
        let app = Application {
            Get("/") {
                "Daylily is awake."
            }

            Get("/hello") {
                "Daylily ships."
            }

            Get("/users/:id") { request in
                let id = try request.parameters.require("id", as: Int.self)
                return "User \(id)"
            }

            Get("/search") { request in
                let term = try request.query.require("term", as: String.self)
                let page = try request.query.get("page", as: Int.self) ?? 1
                return "Search \(term) page \(page)"
            }

            Get("/headers") { request in
                try request.headers.require("x-daylily", as: String.self)
            }

            Get("/json/health") {
                JSON(HealthPayload(status: "ok"))
            }

            Post("/json/echo") { request in
                let input = try await request.json(EchoPayload.self)
                return JSON(EchoResponse(echo: input.message))
            }

            Post("/echo") { request in
                try await request.body.string(upTo: .kilobytes(64))
            }

            Put("/users/:id") { request in
                let id = try request.parameters.require("id", as: Int.self)
                let body = try await request.body.string(upTo: .kilobytes(64))
                return "Updated user \(id): \(body)"
            }

            Patch("/users/:id") { request in
                let id = try request.parameters.require("id", as: Int.self)
                let body = try await request.body.string(upTo: .kilobytes(64))
                return "Patched user \(id): \(body)"
            }

            Delete("/users/:id") {
                Status.noContent
            }

            Head("/health") {
                Status.ok
            }

            Options("/health") {
                Status.noContent
            }
        }

        try await app.run()
    }
}
```

生态模块之前，lifecycle hooks 已经可用：

```swift
let app = Application {
    Get("/hello") { "ok" }
}
.configure {
    // register configuration
}
.boot {
    // open resources
}
.started {
    // server has bound successfully
}
.shutdown {
    // stop accepting work
}
.cleanup {
    // release resources
}
```

默认值不够时，可以使用显式 server configuration：

```swift
try await app.run(
    configuration: ServerConfiguration(
        host: "0.0.0.0",
        port: 8080
    )
)
```

## Dependencies

Daylily 提供了一个很小的 app-wide `Dependencies` registry，用来覆盖常见 service wiring：

```swift
struct ProductService: Sendable {
    func list() async throws -> [Product] {
        []
    }
}

let app = Application(dependencies: { dependencies in
    dependencies.register(ProductService())
}) {
    Get("/products") { request in
        let service = try request.dependencies.require(ProductService.self)
        return JSON(try await service.list())
    }
}
```

这个 registry 按 concrete `Sendable` 类型注册和读取：

```swift
var dependencies = Dependencies()
dependencies.register(ProductService())

let service = try dependencies.require(ProductService.self)
let optional: ProductService? = dependencies.get()
```

这是默认工具，不是强制架构。继续捕获你自己的 services 也完全合法：

```swift
let services = MyServices()

let app = Application {
    Get("/products") { _ in
        try await services.products.list()
    }
}
```

写 app factory 时，优先提供业务语义明确的参数，再保留
`configureDependencies` 作为测试和高级 wiring 的出口：

```swift
public func makeApplication(productService: ProductService = .live) -> Application {
    makeApplication(configureDependencies: { dependencies in
        dependencies.register(productService)
    })
}

public func makeApplication(
    configureDependencies: @Sendable (inout Dependencies) -> Void
) -> Application {
    Application(dependencies: configureDependencies) {
        Get("/products") { request in
            let service = try request.dependencies.require(ProductService.self)
            return JSON(try await service.list())
        }
    }
}
```

测试里通常可以直接 override 业务 service：

```swift
let client = TestClient(makeApplication(productService: .stub([])))
```

完整 pattern 见 [Dependencies Usage](docs/examples/dependencies.md)。

## Runtime Middleware

Middleware 已支持 application、group、route 三个作用域：

```swift
struct HeaderMiddleware: Middleware {
    func handle(_ request: Request, next: Handler) async throws -> Response {
        var response = try await next.respond(to: request)
        response.headers["x-daylily"] = "ships"
        return response
    }
}

let app = Application {
    Group("/api") {
        Get("/health") {
            "ok"
        }
    }
    .middleware(HeaderMiddleware())

    Get("/hello") {
        "Daylily ships."
    }
}
.middleware(HeaderMiddleware())
```

执行顺序是：

```text
application -> router dispatch -> group -> route -> handler
```

Middleware 可以读 `request.body`，但 `RequestBody` 是 one-shot。middleware 消费 body 后再调用 `next`，下游看到的就是已经被消费过的 body。Daylily 不做隐藏的 body replay。

如果 middleware 明确需要检查 body bytes，并且还要把等价 body 继续传给下游，就使用显式 buffering：

```swift
struct SignatureMiddleware: Middleware {
    func handle(_ request: Request, next: Handler) async throws -> Response {
        try await request.withBufferedBody(upTo: .megabytes(1)) { replayed, bytes in
            try verify(bytes)
            return try await next.respond(to: replayed)
        }
    }
}
```

replacement body 依然是 one-shot，而且 helper 必须传入明确的大小限制。

## Observability

`DaylilyObservability` 提供 request ID 和 request logging middleware，同时不把 logging backend 或 tracing 依赖塞进 `DaylilyCore`：

```swift
let app = Application {
    Get("/hello") { request in
        request.daylilyRequestID ?? "missing"
    }
}
.middleware(RequestIDMiddleware())
.middleware(RequestLoggingMiddleware(sink: ConsoleRequestLogSink()))
```

`RequestIDMiddleware` 总是生成 Daylily 自己的 `x-daylily-request-id`。传入的 `x-request-id` 会被当成外部 correlation data，而不是 Daylily 的唯一 request identity。没有传入 `x-request-id` 时，Daylily 会把生成的 request ID 写入 `x-request-id`，用于生态兼容。

`RequestLoggingMiddleware` 会记录 method、path、最终 status、request ID、外部 correlation ID、duration 和公开 error reason。`InMemoryRequestLogSink` 可用于行为检查和早期测试。

## Route Metadata

Route 现在可以携带 runtime metadata，后续 OpenAPI generator 不需要从源码里猜：

```swift
let app = Application {
    Post("/users") {
        Status.created
    }
    .describe(
        summary: "Create user",
        tags: ["Users"],
        inputs: [
            .header("x-daylily", type: "String"),
        ],
        requestBody: .json("CreateUserInput"),
        responses: [
            .response(.created, contentType: "application/json", type: "UserResponse"),
        ]
    )
}

let document = app.openAPI(title: "Daylily Demo", version: "0.1.0")
```

`DaylilyOpenAPI` 会把 route metadata 映射成一个最小 OpenAPI document。它会把 Daylily 的 `/users/:id` 转成 OpenAPI 的 `/users/{id}`。

这个 document 是 `Codable`，所以可以使用已有的 `JSON(...)` response wrapper：

```swift
let response = JSON(document)
```

这仍然是 MVP。Swift 类型的深度 schema 推导会放到后续任务。

## DaylilyTesting

`DaylilyTesting` 提供不走真实网络的测试辅助：

```swift
import Daylily
import DaylilyTesting

let app = Application {
    Get("/hello") {
        "Daylily ships."
    }
}

let response = try await TestClient(app).get("/hello")

try response.requireStatus(.ok)
try response.requireBody("Daylily ships.")
```

它也包含 request builders 和 JSON assertions：

```swift
struct EchoPayload: Codable, Equatable, Sendable {
    let message: String
}

struct EchoResponse: Codable, Equatable, Sendable {
    let echo: String
}

let request = try TestRequest
    .post("/json/echo")
    .withJSON(EchoPayload(message: "hi"))

let jsonResponse = try await TestClient(app).send(request)

try jsonResponse.requireStatus(.ok)
try jsonResponse.requireJSON(EchoResponse(echo: "hi"))
```

`TestClient` 会直接调用 `Application.respond(to:)`，所以测试覆盖的是同一套 in-memory runtime 行为，不需要打开 socket。

## Macro API MVP

Daylily 的 macro MVP 已支持这种形态：

```swift
import Daylily

struct HealthPayload: Codable, Sendable {
    let status: String
}

struct CreateUserInput: Codable, Sendable {
    let name: String
}

@main
@DaylilyServer
struct App {
    @GET("/hello")
    func hello() -> String {
        "Daylily ships."
    }

    @GET("/users/:id")
    func user(@Path id: Int) -> String {
        "User \(id)"
    }

    @GET("/accounts/:id")
    func account(@Path("id") accountID: Int) -> String {
        "Account \(accountID)"
    }

    @GET("/health")
    func health() -> JSON<HealthPayload> {
        JSON(HealthPayload(status: "ok"))
    }

    @POST("/users")
    func create(@Body input: CreateUserInput) -> Status {
        .created
    }

    @PUT("/users/:id")
    func update(@Path id: Int, req: Request) async throws -> String {
        "updated"
    }

    @PATCH("/users/:id")
    func patch(@Path id: Int, req: Request) async throws -> String {
        "patched"
    }

    @DELETE("/users/:id")
    func delete(@Path id: Int) -> Status {
        .noContent
    }

    @HEAD("/health")
    func head() -> Status {
        .ok
    }

    @OPTIONS("/health")
    func options() -> Status {
        .noContent
    }

    @GET("/search")
    func search(
        @Query term: String,
        @Query("page") pageNumber: Int,
        @Header("x-daylily") token: String
    ) -> String {
        "\(term):\(pageNumber):\(token)"
    }

    @GROUP("/api")
    struct API {
        @GET("/health")
        func health() -> String {
            "ok"
        }
    }
}
```

规则很简单：宏必须展开到 runtime route system。runtime 仍然是框架的真相来源。

Macro API 是默认便利路径，不是构建 Daylily app 的唯一方式。如果项目需要自己的 composition root、非默认初始化，或者超出 macro MVP 的 handler 形状，就直接使用 runtime DSL。

宏里的 typed inputs 也会降级成 runtime route metadata。`@Path`、`@Query`、`@Header` 和主写法 `@Body` 会通过手写 route 同款的 `Route.describe(...)` 模型贡献 OpenAPI-ready metadata。`@JSONBody` 只作为 `@Body` 的兼容别名写法保留。

MVP 限制：

- handler 必须是 instance method；
- server type 必须可以通过 `Self()` 默认初始化；
- handler 可以没有参数，可以有一个 `Request` 参数，可以有 `@Path`、`@Query`、`@Header` 参数，也可以有一个 `@Body` 参数；`@JSONBody` 作为兼容别名写法也会被接受；
- `@Path` 会降级到 `req.parameters.require(_:as:)`；
- `@Path` 名称必须匹配 `:name` route segment；
- `@Query` 会降级到 `req.query.require(_:as:)`；
- `@Header` 会降级到 `req.headers.require(_:as:)`；
- `@Body` 会降级到 `try await req.json(Type.self)`；`@JSONBody` 是同样 lowering 的兼容别名写法；
- raw one-shot request body 类型是 `RequestBody`；
- group type 必须可以默认初始化；
- optional typed inputs、macro middleware attributes、protocol/keyed DI runtime implementation 和深度 OpenAPI schema 推导都是后续工作。

这些是 macro MVP 的限制，不是 runtime 的限制。

## AI-Native 开发

Daylily 的设计目标之一，是让 AI 可以第一时间变得有用。

我们不希望 AI 通过翻散落的源码去猜项目架构，而是给它一套明确的 AIDEV 系统：

- [AIDEV.md](AIDEV.md)：AI 开发主入口。
- [ai/aidev/start-here.md](ai/aidev/start-here.md)：AI 接手项目时第一个应该读的文件。
- [ai/aidev/project-map.md](ai/aidev/project-map.md)：模块、文件和职责地图。
- [ai/aidev/architecture.md](ai/aidev/architecture.md)：依赖方向和边界规则。
- [ai/aidev/runtime-contracts.md](ai/aidev/runtime-contracts.md)：组件输入、输出、保证和扩展点。
- [ai/aidev/api-registry.md](ai/aidev/api-registry.md)：当前 public API 表。
- [ai/aidev/extension-playbooks.md](ai/aidev/extension-playbooks.md)：新增 HTTP verb、JSON、middleware、streaming body、macro、transport 和 check 的操作手册。
- [ai/epics](ai/epics)：主题级规划容器。
- [ai/tasks](ai/tasks)：task 级执行记录；task 是最小 commit/push 单位。
- [ai/aidev/registry.yml](ai/aidev/registry.yml)：机器可读项目注册表。
- [ai/prompts/daylily-agent.md](ai/prompts/daylily-agent.md)：给未来 AI agent 的标准提示词。

这意味着用户可以很自然地让 AI：

- 解释 Daylily 的运行方式；
- 添加新的 HTTP verb；
- 扩展 JSON 支持；
- 设计 middleware；
- 实现宏；
- 更新 public API 注册表；
- 编写或更新检查；
- 使用已知命令验证项目。

AI 不需要从零重新理解项目。它从 AIDEV 契约开始，做一个边界清晰的改动，必要时更新契约，然后运行验证。

## 项目结构

```text
Daylily/
├── AIDEV.md
├── DAYLILY_NOTES.md
├── Package.swift
├── README.md
├── README.zh-CN.md
├── docs/
├── Sources/
│   ├── Daylily/
│   ├── DaylilyCore/
│   ├── DaylilyJSON/
│   ├── DaylilyNIO/
│   ├── DaylilyObservability/
│   ├── DaylilyOpenAPI/
│   ├── DaylilyTesting/
│   ├── DaylilyCheckSuite/
│   └── HelloDaylily/
├── Tests/
│   └── DaylilyTests/
└── ai/
    ├── epics/
    ├── aidev/
    ├── prompts/
    └── tasks/
```

## 架构规则

最重要的不变量：

- `DaylilyCore` 不能依赖 NIO。
- 用户侧 API 不能暴露 NIO 类型。
- runtime API 先于宏语法糖。
- `swift run` 应该一直能启动示例服务。
- `swift test` 应该一直通过。
- `swift run HelloDaylily --check` 应该一直通过。
- public API 变化必须同步更新 AIDEV。

## 路线图

近期：

1. 设计 dependency lifecycle integration。
2. 增加 middleware macro attributes。
3. 扩展 OpenAPI schema generation。
4. 发布 benchmark methodology。

## License

Daylily 使用 [MIT License](LICENSE) 发布。
