# Daylily

[English](README.md) | 简体中文

[![CI](https://github.com/sinduke/Daylily/actions/workflows/ci.yml/badge.svg)](https://github.com/sinduke/Daylily/actions/workflows/ci.yml)

Daylily 是一个实验性的 AI-native Swift Web 框架。

它一开始刻意保持很小：一个声明式 runtime、一个基于 NIO 的 HTTP server，以及一套 AIDEV 契约。AIDEV 的目标是让 AI 不需要先翻源码，也能快速理解、使用、升级和扩展这个项目。

> 还在等？Daylily 已经发货了。

## 为什么是 Daylily

服务端 Swift 的底层基础很强，但上层框架的演进经常显得缓慢、不透明。Daylily 选择另一条路：

- 先把 runtime 做扎实。
- 保持 core 足够小。
- 不把 transport 细节暴露给用户 API。
- 默认拥抱 Swift Concurrency。
- 宏只是声明式语法糖，不是框架的真相来源。
- 从第一天开始就让 AI 通过架构地图、契约、注册表、任务和扩展手册参与开发。

Daylily 不是 Vapor 或 Hummingbird 的复制品。它是在探索：如果 AI 辅助开发从一开始就是架构的一部分，一个 Swift Web 框架应该长什么样。

## 当前状态

已经实现：

- Swift package 骨架。
- `Application` runtime。
- 声明式路由 DSL：`Get`、`Post`、`Group`。
- `:name` 形式的路径参数。
- 运行时类型化路径参数提取。
- 运行时类型化 query 和 header 提取。
- `Request`、`Response`、`Status`、`Headers`、`Parameters`。
- Daylily 自有的 `Body` request body 模型。
- 基于 `ByteChunk` 和 `ByteCount` 的 one-shot body 消费。
- 真正的 NIO request body streaming bridge，带有有界缓冲和实用 backpressure。
- 支持 application、group、route 作用域的 runtime middleware。
- Application lifecycle hooks：`configure`、`boot`、`started`、`shutdown`、`cleanup`。
- 默认 SIGINT/SIGTERM graceful server shutdown。
- 显式的 `withBufferedBody(upTo:_:)` helper，用于有界 body 检查和 replacement。
- `String`、`Status`、`Response` 的 `ResponseConvertible` 支持。
- 通过 `request.body.json(...)` 和 `request.json(...)` 异步解码 JSON body。
- 通过 `JSON(...)` 返回 JSON response。
- 基于 NIO 的 HTTP/1.1 server。
- Macro route/group MVP：`@DaylilyServer`、`@GET`、`@POST`、`@GROUP`。
- Macro `@Path` 类型化路径参数注入。
- Macro `@Query` 和 `@Header` 类型化输入注入。
- Macro `@JSONBody` 类型化 JSON body 注入。
- `DaylilyTesting` in-memory `TestClient`、request builders 和 JSON assertions。
- 默认 `swift run` 示例服务。
- 轻量行为检查。
- AIDEV 项目接管系统。

还没有实现：

- `@Path`、`@Query`、`@Header`、`@JSONBody` 之外的宏级类型化输入注入（真正的 `@Body` 写法、optional values 等）。
- OpenAPI 生成。
- 生产级 server 控制。
- 依赖注入。
- Macro middleware attributes。

## 快速开始

在项目根目录执行：

```sh
swift build
swift run HelloDaylily --check
swift run
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
printf 'abcdef' | curl --http1.1 -H 'Transfer-Encoding: chunked' -H 'Content-Length:' --data-binary @- http://127.0.0.1:8080/upload/count
curl http://127.0.0.1:8080/json/health
curl -X POST -H 'content-type: application/json' --data '{"message":"hi"}' http://127.0.0.1:8080/json/echo
```

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

Middleware 可以读 `request.body`，但 `Body` 是 one-shot。middleware 消费 body 后再调用 `next`，下游看到的就是已经被消费过的 body。Daylily 不做隐藏的 body replay。

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
    func create(@JSONBody input: CreateUserInput) -> Status {
        .created
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

MVP 限制：

- handler 必须是 instance method；
- server type 必须可以通过 `Self()` 默认初始化；
- handler 可以没有参数，可以有一个 `Request` 参数，可以有 `@Path`、`@Query`、`@Header` 参数，也可以有一个 `@JSONBody` 参数；
- `@Path` 会降级到 `req.parameters.require(_:as:)`；
- `@Path` 名称必须匹配 `:name` route segment；
- `@Query` 会降级到 `req.query.require(_:as:)`；
- `@Header` 会降级到 `req.headers.require(_:as:)`；
- `@JSONBody` 会降级到 `try await req.json(Type.self)`；
- 真正的 `@Body` 写法暂缓，因为 `Body` 已经是 Daylily 的 raw request body 类型；
- group type 必须可以默认初始化；
- optional typed inputs、macro middleware attributes、DI、OpenAPI 都是后续工作。

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
├── Sources/
│   ├── Daylily/
│   ├── DaylilyCore/
│   ├── DaylilyJSON/
│   ├── DaylilyNIO/
│   ├── DaylilyTesting/
│   └── HelloDaylily/
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
- `swift run HelloDaylily --check` 应该一直通过。
- public API 变化必须同步更新 AIDEV。

## 路线图

近期：

1. 生产级 server 控制。
2. Observability middleware。
3. OpenAPI metadata，然后再扩生态模块。

## License

Daylily 使用 [MIT License](LICENSE) 发布。
