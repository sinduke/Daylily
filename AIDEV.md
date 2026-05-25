# AIDEV

`AIDEV.md` 是 Daylily 的 AI 开发入口文件。

任何 AI 或人类在修改 Daylily 之前，都应该先阅读本文件以及 `ai/aidev/` 下的项目约束。它的目的不是替代代码，而是让后续开发有稳定的地图、边界和判断标准。

Daylily 的约定是：

> AI 理解项目、规划升级、判断架构、设计扩展时，以 AIDEV 为权威入口。源码只作为执行修改时的落点，不作为重新猜测项目结构的主要依据。

## 核心原则

Daylily 的开发方式：

> 人类定方向、审美和边界；AI 推进实现、测试、文档和示例；CI 或本地检查负责裁判。

当前阶段的最高优先级：

1. 保持项目可以 `swift build`。
2. 保持默认 `swift run` 可以启动 HelloDaylily。
3. 保持 `swift run HelloDaylily --check` 可以通过核心行为检查。
4. 公共 API 变更必须同步更新 AIDEV 文档。
5. 新功能先进入 runtime，再考虑宏糖。

## 必读地图

- [Start Here](ai/aidev/start-here.md): AI 接手项目的第一入口。
- [Project Map](ai/aidev/project-map.md): 当前目录、模块、文件职责。
- [Architecture](ai/aidev/architecture.md): 架构边界、依赖方向、transport 规则。
- [Concepts](ai/aidev/concepts.md): Daylily 的核心概念和心智模型。
- [Runtime Contracts](ai/aidev/runtime-contracts.md): runtime 各组件的输入、输出、保证和扩展点。
- [API Registry](ai/aidev/api-registry.md): 当前公共类型、函数、方法、参数约定。
- [Conventions](ai/aidev/conventions.md): 命名、错误、路由、handler、响应约定。
- [Invariants](ai/aidev/invariants.md): 不可破坏规则。
- [Extension Playbooks](ai/aidev/extension-playbooks.md): 新增能力时的固定打法。
- [Task Protocol](ai/aidev/task-protocol.md): AI 任务文件格式和执行协议。
- [Workflow](ai/aidev/workflow.md): AI 开发流程、任务文档、验证命令。
- [Roadmap](ai/aidev/roadmap.md): 当前阶段与下一步任务。
- [Registry YAML](ai/aidev/registry.yml): 机器可读的项目索引。
- [Agent Prompt](ai/prompts/daylily-agent.md): 给接手 AI 的标准提示词。

## 当前验证命令

在项目根目录执行：

```sh
swift build
swift run HelloDaylily --check
swift run
```

`swift run` 会启动 HTTP server，监听：

```text
http://127.0.0.1:8080
```

当前示例服务包含基础文本路由和 JSON 路由：

```sh
curl http://127.0.0.1:8080/hello
curl http://127.0.0.1:8080/json/health
curl -X POST -H 'content-type: application/json' --data '{"message":"hi"}' http://127.0.0.1:8080/json/echo
```

## 修改规则

修改 Daylily 时遵守：

- 不让 `DaylilyCore` 依赖 NIO。
- 不让 public API 暴露 `EventLoopFuture`、`ChannelHandler`、`ByteBuffer`。
- 新路由能力先能用 runtime 表达，再用宏包装。
- 如果新增、删除、重命名 public 类型或函数，更新 `ai/aidev/api-registry.md` 和 `ai/aidev/registry.yml`。
- 如果改变模块边界，更新 `ai/aidev/project-map.md` 和 `ai/aidev/architecture.md`。
- 如果引入新命令或验证方式，更新 `README.md`、`AIDEV.md` 和相关 task。
- 如果 AIDEV 与源码不一致，优先修正 AIDEV 或明确记录源码偏差，不能让 AI 依赖隐含知识继续推进。
