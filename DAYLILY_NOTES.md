# Daylily Project Notes

本文档整理当前关于 Daylily 的核心讨论，作为后续架构分析、任务拆解和 AI 驱动开发的起点。

## 1. 项目动机

当前 Swift 服务端生态主要框架是 Vapor 和 Hummingbird。

- Vapor 生态成熟，但 Vapor 5 进展缓慢，长期处在“未来版本快来了”的状态。
- Hummingbird 更轻量、现代、模块化，但不是完整全家桶，很多能力需要自己组合。
- Swift 语言、Swift Concurrency、宏系统、HTTPTypes、ServiceLifecycle 等基础能力已经成熟到可以支撑新的服务端框架体验。

Daylily 的核心机会不是“再写一个 Vapor”，而是：

> 写一个 AI-native、Swift Concurrency first、声明式、宏驱动、可快速演进的 Swift 服务端框架。

人类负责方向、审美和架构边界；AI 负责高速推进实现、测试、文档、示例和基准测试；CI 负责当裁判。

## 2. 名字与品牌

当前项目代号：`Daylily`

含义：

- 表面是英文植物名，优雅、自然、适合 Swift 包名。
- 中文语境暗含“黄花菜都凉了”，有嘲讽感但不直接冒犯。
- 适合作为 repo、package、module、codename。

可能的 slogan：

- `Still waiting? Daylily already shipped.`
- `SwiftUI for servers, without pretending servers are views.`
- `Built for the age where waiting two years for a beta is no longer a strategy.`

正式包名可以先使用：

```swift
import Daylily
```

核心类型与协议命名后续再定，但外部品牌先围绕 `Daylily` 展开。

## 3. API 方向

我们不希望采用传统命令式注册路由：

```swift
let app = Application()

app.get("/hello") { _ in
    "Daylily ships."
}

try await app.run()
```

这个形态太像 Vapor/Hummingbird，只是换壳。

Daylily 应该走 SwiftUI 式声明体验，进一步使用 Swift attached macros 做路由声明。

目标形态：

```swift
@main
@DaylilyServer
struct DaylilyDemo {
    @GET("/hello")
    func hello() -> String {
        "Daylily ships."
    }

    @GET("/users/:id")
    func user(req: Request) -> UserResponse {
        let id = req.parameters.id
        return UserResponse(id: id)
    }

    @GROUP("/api", middleware: Auth.self)
    struct API {
        @GET("/health")
        func health() -> [String: String] {
            ["status": "ok"]
        }

        @POST("/users")
        func createUser(req: Request) async throws -> UserResponse {
            let input = try await req.json(CreateUserRequest.self)
            return try await Users.create(input)
        }
    }
}
```

更进一步的参数注入形态：

```swift
@GET("/users/:id")
func user(@Path id: UUID) async throws -> UserResponse {
    try await users.find(id)
}

@POST("/users")
func create(@Body input: CreateUserRequest) async throws -> UserResponse {
    try await users.create(input)
}
```

宏系统建议分层：

- `@DaylilyServer`
- `@GET`, `@POST`, `@PUT`, `@PATCH`, `@DELETE`
- `@GROUP`
- `@Path`, `@Query`, `@Body`, `@Header`, `@Cookie`
- `@Service` 或类似依赖注入机制

注意：Swift attached macros 是附着在声明上的，适合挂在 `struct`、`func`、`var` 等声明上，不适合直接装饰一个裸闭包表达式。

## 4. 核心定位

Daylily 应该是：

- Swift Concurrency first
- Macro first, but runtime not macro dependent
- HTTPTypes friendly
- NIO hidden, not NIO leaked
- Streaming body first
- Small core, extensible modules
- AI-native development workflow

一句话：

> Macro-generated route graph + async-first runtime + NIO transport + typed request extraction.

## 5. 底层原则

Daylily 表面像 SwiftUI，底层像一个克制的系统框架。

宏负责甜，runtime 负责稳，transport 负责扛。

所有高级 API 最终都应该编译或转换成统一的路由描述：

```swift
Route(
    method: .get,
    path: "/users/:id",
    handler: GeneratedHandler(...)
)
```

宏只是用户体验层，底层 runtime 应该也支持非宏 API，方便测试、插件和内部生成：

```swift
Route.get("/hello") {
    "hello"
}
```

## 6. Transport 策略

当前判断：Swift 服务端还没有真正替代 SwiftNIO 的成熟官方服务器底座。

趋势不是“去 NIO”，而是“隐藏 NIO”：

```text
过去:
用户代码 -> Vapor/Hummingbird -> NIO Future/EventLoop/ByteBuffer

现在:
用户代码 -> async/await + HTTPTypes + ServiceLifecycle -> framework runtime -> NIO
```

Daylily 不应该反 NIO，而应该反 NIO 泄漏。

建议设计：

```swift
protocol ServerTransport {
    func run(
        configuration: ServerConfiguration,
        responder: @Sendable @escaping (Request) async throws -> Response
    ) async throws
}
```

第一实现：

```text
DaylilyNIOTransport
```

未来可以实验：

```text
DaylilyNetworkTransport
DaylilyLambdaTransport
DaylilyTestTransport
```

但生产 Linux HTTP server 第一阶段不建议绕开 NIO，否则会陷入 socket、epoll/kqueue、TLS、HTTP parser、HTTP/2、backpressure 等底层黑洞。

## 7. 流式请求体

NIO 本质上支持流式 HTTP request。

NIO 的 HTTP request 通常拆成：

```swift
HTTPServerRequestPart.head(HTTPRequestHead)
HTTPServerRequestPart.body(ByteBuffer)
HTTPServerRequestPart.end(HTTPHeaders?)
```

也就是：

```text
请求头 -> 0 个或多个 body chunk -> 请求结束
```

Daylily 不应该把这个低层事件模型暴露给用户，而应该包装成 Swift Concurrency 风格：

```swift
@POST("/upload")
func upload(@Body(.stream) body: BodyStream) async throws -> UploadResult {
    for try await chunk in body.bytes {
        try await storage.write(chunk)
    }

    return .ok
}
```

普通业务 API：

```swift
try await req.body.json(UserInput.self)
try await req.body.bytes.collect(limit: 1024 * 1024)

for try await chunk in req.body.bytes {
    try await storage.write(chunk)
}
```

关键点：

- 大 body 不应该默认读进内存。
- 必须支持 backpressure。
- 写磁盘、写 S3、代理转发、AI streaming response 都应该走流式模型。
- `@Body` 默认适合小 JSON；`@Body(.stream)` 明确进入流式模式。

## 8. Router

Router 是性能核心，不应该线性扫描。

建议使用 trie / radix tree。

路径：

```text
GET /users/:id/posts/:postID
```

树：

```text
root
└── users
    └── :id
        └── posts
            └── :postID
```

Segment 类型：

```swift
enum Segment {
    case literal(String)
    case parameter(String)
    case wildcard(String)
}
```

匹配优先级：

```text
literal > parameter > wildcard
```

这样 `/users/me` 不会被 `/users/:id` 错吃。

## 9. Request / Response

Request 应该轻，不默认聚合 body。

Response 应该支持：

- `String`
- `Codable`
- `Status`
- `Response`
- `AsyncSequence` body stream

统一协议方向：

```swift
protocol ResponseConvertible {
    func encodeResponse(context: ResponseContext) async throws -> Response
}
```

Handler 建议统一成：

```swift
async throws -> ResponseConvertible
```

用户不接触 `EventLoopFuture`。

## 10. Middleware

Middleware 需要能作用在：

- Application
- Group
- Route

执行顺序：

```text
global -> group -> route -> handler
```

底层协议：

```swift
protocol Middleware {
    func handle(
        _ request: Request,
        next: Handler
    ) async throws -> Response
}
```

宏层语法可以是：

```swift
@GROUP("/api")
@Use(Auth())
@Use(RateLimit())
struct API {
    ...
}
```

或者：

```swift
@GROUP("/api", middleware: Auth.self)
struct API {
    ...
}
```

具体形式后续定。

## 11. Dependency Injection

不要一开始设计过重 IoC。

方向：

```swift
func user(
    @Path id: UUID,
    @Service users: UserService
) async throws -> User {
    try await users.find(id)
}
```

底层可以是 typed container：

```swift
app.services.register(UserService.self) {
    LiveUserService(...)
}
```

原则：

- 避免全局单例魔法。
- 支持 application scope 和 request scope。
- 让测试替换服务足够容易。

## 12. Error Model

错误模型第一天就要设计好。

方向：

```swift
protocol HTTPError: Error {
    var status: Status { get }
    var reason: String { get }
}
```

常用：

```swift
throw Abort(.notFound)
throw ValidationError(...)
throw Unauthorized()
```

统一 error handler：

```swift
app.errors.use { error, request in
    ...
}
```

生产环境隐藏内部错误，开发环境提供清晰 debug 信息。

## 13. Lifecycle

服务启动不只是 `run()`。

需要生命周期：

```text
configure
boot
started
shutdown
cleanup
```

数据库连接池、Redis、任务队列等都应该挂到 lifecycle 上。

必须支持 graceful shutdown。

## 14. Observability

从第一天内置：

- structured logging
- request id
- latency
- status code
- error logging
- tracing hook
- metrics hook

默认日志应该简洁：

```text
GET /users/123 200 4.2ms
POST /login 401 1.1ms
```

内部结构化字段要完整，方便生产系统接入。

## 15. Testing

Daylily 的测试体验要强。

目标：

```swift
@Test
func hello() async throws {
    let app = TestApp(Server.self)

    let res = try await app.get("/hello")

    #expect(res.status == .ok)
    #expect(try res.text() == "Daylily ships.")
}
```

不需要真的开端口。测试 transport 直接调用 handler pipeline。

## 16. Package Layout

建议模块：

```text
Daylily
DaylilyCore
DaylilyHTTP
DaylilyMacros
DaylilyNIO
DaylilyOpenAPI
DaylilyTesting
DaylilyAuth
DaylilyPostgres
DaylilyRedis
DaylilyCLI
```

`Daylily` 主模块 re-export 常用能力。

内部保持模块边界清楚，避免主包无限膨胀。

## 17. MVP 范围

第一阶段不要做 ORM。

ORM 是黑洞，会拖慢核心节奏。

MVP 应该死磕：

- macro routes
- route graph generation
- async handlers
- request / response
- JSON body decode / encode
- streaming request body
- middleware
- error handling
- testing client
- logging
- hello-world benchmark
- basic OpenAPI metadata

第一阶段目标示例：

```swift
@main
@DaylilyServer
struct App {
    @GET("/")
    func index() -> String {
        "Daylily ships."
    }

    @GET("/users/:id")
    func user(@Path id: UUID) async throws -> UserResponse {
        try await users.find(id)
    }

    @POST("/upload")
    func upload(@Body(.stream) body: BodyStream) async throws -> UploadResult {
        for try await chunk in body.bytes {
            try await storage.write(chunk)
        }

        return .ok
    }
}
```

## 18. AI-Native 开发方式

仓库建议内置：

```text
ai/specs/
ai/tasks/
ai/adr/
ai/evals/
ai/prompts/
```

用途：

- `ai/specs/`: 功能规格
- `ai/tasks/`: 可执行任务拆分
- `ai/adr/`: 架构决策记录
- `ai/evals/`: 行为验证和回归检查
- `ai/prompts/`: 标准开发提示词

公开计分板可以包括：

- 本周完成任务数
- 测试覆盖率
- benchmark
- 最新 release 日期
- AI 完成的 PR 数
- human-reviewed 比例

这比单纯嘲讽更有杀伤力：别人慢，我们透明地快。

## 19. 外部事实快照

截至当前讨论：

- Vapor 仍然基于 SwiftNIO。
- Hummingbird 仍然基于 SwiftNIO。
- Swift HTTPTypes 是 HTTP message currency types，不是 transport 替代品。
- ServiceLifecycle 适合管理服务生命周期。
- NIO 有流式 HTTP 请求模型，但 API 底层。

参考：

- https://github.com/vapor/vapor
- https://docs.vapor.codes/advanced/server/
- https://github.com/hummingbird-project/hummingbird
- https://www.swift.org/blog/introducing-swift-http-types/
- https://github.com/apple/swift-nio
- https://github.com/swift-server/async-http-client

## 20. 待决问题

后续需要重点讨论：

1. `@GROUP` 应该挂在 nested struct 上，还是也支持 function/property group builder？
2. `@Path id: UUID` 这类参数注入第一版是否实现，还是先用 `Request`？
3. 宏展开后生成 route registry 的具体形式。
4. runtime 是否要求 `Server` 是 value type，还是允许 actor/class controller？
5. handler 是否默认初始化 `Self()`，如何处理 stateful services？
6. DI 容器的最小可用模型。
7. `BodyStream` 的 chunk 类型使用 `ByteBuffer`、`Data`，还是自定义 `Bytes`？
8. HTTPTypes 在内部 request/response 中的边界。
9. OpenAPI metadata 是宏直接生成，还是 runtime route graph 反射生成？
10. 第一版 benchmark 对标对象和指标。

