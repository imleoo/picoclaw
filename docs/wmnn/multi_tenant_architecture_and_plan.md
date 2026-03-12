# PicoClaw 架构演进文档：WMNN 分布式多租户架构与开发计划

**文档版本**：v1.0
**目标读者**：研发团队、架构师
**背景**：将 PicoClaw 从单机轻量级 AI Agent 引擎升级为能够支撑 1000 人以上并发访问、具有完全数据隔离和分布式高可用的多租户 AI 平台。

---

## 一、核心重构思想：无状态化与 UDS 融合
当前 PicoClaw 的核心瓶颈在于：强依赖本地文件系统（Markdown 工作区存放 Prompt/状态/记忆，JSON 存放会话与定时任务），导致实例**有状态 (Stateful)** 且在千人并发下极易引发 **I/O 阻塞乃至进程崩溃**。

改造的核心是将所有 I/O 操作摘除，通过强力解耦，全面拥抱 WMNN 内部自研基建 **UDS (Universal Data Service) SDK (`github.com/nnys/datacenter/sdks/go`)**，将 PicoClaw 升级为纯粹的**无状态计算节点 (Stateless Node)**。

---

## 二、架构设计图谱（四大核心层）

### 2.1 存储与持久化层 (Storage & Persistence Layer)
彻底摒弃本地盘，所有数据流向 UDS：
- **分布式事务与互斥锁 (UDS KV)**：
  - 各级聊天临时状态（如“思考中”、“排队中”）、API 令牌桶计数器、分布式任务重叠执行的互斥锁（利用 `client.SetNX`），均存储在极低延迟的 UDS KV 中。
- **对话流与基础配置 (UDS Model - PostgreSQL)**：
  - 用户的账户数据关系、群组黑白名单、每个 Bot 的运行参数 (`bot_configs` 表) 及核心对话中短期历史记录，通过 UDS Model SDK (`client.Model("bots")...`) 存储在 PostgreSQL。
- **Agent 外挂语义记忆库 (UDS Vector)**：
  - 废弃庞大的单文件 `MEMORY.md`。使用 UDS Vector 接口 (`VectorUpsert`/`VectorSearch`) 实现**向量化记忆存储**。在千人并发级别下，实现毫秒级的跨轮长对话语义回捞，且无需每次消耗大量 Token 重读文档。
- **资产与技能沙箱 (UDS Blob)**：
  - 将每个 Bot 特有的复杂的 Identity 设定、Prompt 模板、自定义 Python/Lua 技能脚本，作为远端对象统一托管在 UDS Bucket，按需在内存中通过流加载。

### 2.2 任务与调度层 (Task & Scheduling Layer)
重写现有的 `pkg/cron` 单点状态机模型：
- **Cron 中心化调度机制**：
  - 定时任务配置注册入 UDS Model (PostgreSQL)。调度器通过数据库行锁保证扫描安全。
- **MQ 异步分发池 (UDS KV List)**：
  - 取消通过 `time.Ticker` 的全局单点触发执行。当时间到达后，调度器仅将包含 `SessionKey` 的任务包推入 UDS KV 的 List (`LPush`)，构成极轻量消息队列。
  - 多个 PicoClaw 节点上的后台 Goroutine Worker 池监听 List (`RPop`)，争抢并并发执行真正的 LLM 请求。

### 2.3 鉴权与安全沙箱层 (Security & Policy Layer)
应对万网复杂环境下的恶意穿透与流量风暴：
- **RBAC 技能调用墙**：
  - 在 `AgentLoop` 通过事件总线获取请求时，校验 `AccountID`。若非授权超管，严禁在 `ContextBuilder` 为其装配诸如 `execute_command` (宿主机代码执行) 等高危系统级 Tool。
- **智能排队与降级 (LLM Rate Limiting)**：
  - 在 `pkg/providers` 中维护一份基于 UDS KV 的令牌桶限流器。若监测到 OpenAI/Anthropic 等 API 的 `429 Too Many Requests` 反压，则触发降级策略，将普通用户的提问平滑切换到本地低开销模型或排队等待。

### 2.4 上游源码同步机制 (Upstream Sync Strategy)
考虑到 PicoClaw 为开源项目，我们的魔改需保障未来能平滑 Merge 上游社区更新：
- **IoC 与目录隔离**：绝不侵入修改核心通信结构 `pkg/agent/loop.go` 和 `pkg/bus`。所有 UDS 功能均作为 `Storage` 和 `Cron` 接口实现，放在新建的 `pkg/uds_adapter/` 目录中，在 `main.go` 启动时做依赖注入。
- **Git Flow 保障**：维护 `main` 分支永远与官方 Upstream 保持同步； WMNN 定制版在 `multi-tenant` 专属分支开发，随时通过 `git rebase main` 享用官方补丁。

---

## 三、开发实施计划 (Development Roadmap)

本项目落地规模约为 3-4 周工作量（单后端研发），建议分为三个 Sprint：

### Sprint 1: 存储基础设施剥离与 UDS 桥接 (Week 1)
**目标**：砍掉本地文件读写，让 Bot 会话能在 UDS 服务上正常运转。
- [ ] **Task 1.1**: 在 `pkg/` 下定义抽象接口 `SessionStore` (管理历史)、`MemStore` (管理长期记忆) 和 `PromptLoader`。
- [ ] **Task 1.2**: 引入 `github.com/nnys/datacenter/sdks/go`，在新建目录 `pkg/storage/uds/` 中实现上述三个接口。
- [ ] **Task 1.3**: 改造 `cmd/picoclaw/main.go`，通过 UDS config 进行初始化 (`NewWithOptions`)，并将 UDS Store 注入至 Agent Registry。
- [ ] **Task 1.4**: 使用 UDS Model 编写建表脚手架 (`resources.yaml`)，打通单发测试对话的 Session 存储。

### Sprint 2: 记忆库升维与多租户权限引擎 (Week 2)
**目标**：具备千人并发级别的外挂记忆检索能力，以及区分 Bot/用户权限制。
- [ ] **Task 2.1**: 改写 `pkg/agent/memory.go`。实现文本嵌入化 (Embedding Pipeline)，对接 UDS Vector 的 `VectorUpsert` 存入零散记忆记忆碎片，和 `VectorSearch` 提取检索。
- [ ] **Task 2.2**: 建立 `bot_configs` 表，每个 Bot 的 Identity 和启用的技能池通过读取 UDS DB/Blob 动态下发至 `ContextBuilder`，消灭本地 `workspace/AGENTS.md`。
- [ ] **Task 2.3**: 增加鉴权中间件 Middleware。拦截所有的事件总线请求，校验 `AccountID` 权限，对高危 Tools 实施硬过滤。

### Sprint 3: 分布式流控与容器化改造 (Week 3)
**目标**：彻底消灭进程单点缺陷，实现云原生弹性扩容。
- [ ] **Task 3.1**: 重写 `pkg/cron/service.go`。抛弃本地互斥锁，改用 UDS KV `SetNX` 实现分布式任务调度获取锁。
- [ ] **Task 3.2**: 引入基于 UDS KV List 的轻量级任务消息队列，拆分解耦 Cron 的 “探测” 与 “执行” 阶段。
- [ ] **Task 3.3**: 在 `pkg/providers/` 为 LLM 客户端增加基于 UDS KV 统筹的 Token 漏桶算法限流排队功能。
- [ ] **Task 3.4**: 编写 `Dockerfile` 与 Kubernetes 部署 YAML。剥离一切挂载卷 (Volumes)，使得 PicoClaw 在多副本 (Replicas) 状态下成功联动启动，无损压测千人请求。
