# Daylily

[English](README.md) | 简体中文

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
- `Request`、`Response`、`Status`、`Headers`、`Parameters`。
- `String`、`Status`、`Response` 的 `ResponseConvertible` 支持。
- 通过 `request.json(...)` 解码 JSON body。
- 通过 `JSON(...)` 返回 JSON response。
- 基于 NIO 的 HTTP/1.1 server。
- Macro route/group MVP：`@DaylilyServer`、`@GET`、`@POST`、`@GROUP`。
- 默认 `swift run` 示例服务。
- 轻量行为检查。
- AIDEV 项目接管系统。

还没有实现：

- Middleware。
- 流式 request body。
- 类型化参数注入。
- OpenAPI 生成。
- 依赖注入。

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
curl -X POST --data 'hi' http://127.0.0.1:8080/echo
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
                "User \(request.parameters.id ?? "unknown")"
            }

            Get("/json/health") {
                JSON(HealthPayload(status: "ok"))
            }

            Post("/json/echo") { request in
                let input = try request.json(EchoPayload.self)
                return JSON(EchoResponse(echo: input.message))
            }

            Post("/echo") { request in
                request.bodyString
            }
        }

        try await app.run()
    }
}
```

## Macro API MVP

Daylily 的 macro MVP 已支持这种形态：

```swift
import Daylily

struct HealthPayload: Codable, Sendable {
    let status: String
}

@main
@DaylilyServer
struct App {
    @GET("/hello")
    func hello() -> String {
        "Daylily ships."
    }

    @GET("/users/:id")
    func user(req: Request) -> String {
        "User \(req.parameters.id ?? "unknown")"
    }

    @GET("/health")
    func health() -> JSON<HealthPayload> {
        JSON(HealthPayload(status: "ok"))
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
- handler 可以没有参数，或者只有一个 `Request` 参数；
- group type 必须可以默认初始化；
- `@Path`、`@Body`、middleware、DI、OpenAPI 都是后续工作。

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
│   └── HelloDaylily/
└── ai/
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

1. 流式 request body。
2. Middleware runtime。
3. 类型化参数提取。
4. OpenAPI metadata。

## License

Daylily 使用 [MIT License](LICENSE) 发布。
