# PicoClaw 架构演进文档：WMNN 分布式多用户改造方案（修订版）

**文档版本**：v1.2  
**修订日期**：2026-03-12  
**目标读者**：研发团队、架构师、运维团队  
**背景**：将 PicoClaw 从单机状态化 Agent 引擎升级为可支撑千人并发、具备多用户隔离和分布式高可用能力的平台。

---

## 一、现状基线（必须先对齐）

### 1.1 真实启动与依赖装配点
当前运行链路不在单一 `cmd/picoclaw/main.go`，而在以下入口完成关键依赖装配：
- `cmd/picoclaw/internal/gateway/helpers.go`：网关模式主装配（AgentLoop、Cron、Heartbeat、Devices、Media、Channels、Health）
- `cmd/picoclaw/internal/agent/helpers.go`：CLI Agent 模式
- `pkg/agent/instance.go`：每个 Agent 的 workspace、session store、context builder、tool registry 初始化

结论：多用户改造不能只改 `main.go`，必须覆盖 gateway/agent helper + `pkg/agent/instance.go`。

### 1.2 项目已具备的能力（不应重复建设）

#### 1.2.1 存储抽象
- 已有会话抽象：`pkg/session/SessionStore`，并有 `JSONLBackend` 适配（分片锁、原子写入）
- 已有存储接口：`pkg/memory/Store`（Add/Get/Set/Truncate/Compact）
- 已有旧 JSON -> JSONL 自动迁移：`memory.MigrateFromJSON`

#### 1.2.2 多用户路由架构（已较完善）
- **七级路由优先级**：peer → parent_peer → guild → team → account → channel → default
- **四级 DM Scope 隔离**：
  - `main`：全局共享会话（默认值，⚠️ 有串读风险）
  - `per-peer`：按用户隔离
  - `per-channel-peer`：按渠道+用户隔离
  - `per-account-channel-peer`：完整隔离
- **跨平台身份关联**：`identity_links` 配置支持跨 Telegram/Discord/Slack 统一用户身份
- **团队/服务器隔离**：支持 `team_id`（Slack）、`guild_id`（Discord）、`parent_peer`（Telegram 论坛）

#### 1.2.3 Provider 与限流
- 已有 provider fallback/cooldown/429 分类
- 指数退避算法：标准错误 1min→5min→25min→1h，计费错误 5h→10h→20h→24h
- 24 小时失败窗口自动重置
- 已有 channel 出站限流、重试、placeholder/typing/reaction 流水线

#### 1.2.4 安全护栏（四层防护，比预期完善）
| 机制 | 实现详情 |
|------|---------|
| **Deny-Pattern** | 30+ 默认规则（rm -rf、format、fork bomb、命令注入等），支持自定义扩展 |
| **路径沙箱** | `restrict_to_workspace` + `os.Root` API 防逃逸 + `allow_read/write_paths` 白名单 |
| **Command Confirm** | Cron 命令执行需 `internal channel` + `command_confirm=true` 双重验证 |
| **Spawn Allowlist** | `subagents.allow_agents` 白名单控制，支持通配符 `*` |
| **远程执行限制** | `allow_remote=false`（默认），仅 `cli/system/subagent` 通道可执行 |

#### 1.2.5 Web 控制平面
- 已有 web control-plane（gateway 进程托管、会话查询、OAuth、模型管理、配置管理）
- **⚠️ 多实例兼容性问题**：Gateway 进程状态、OAuth 流程状态均为内存存储

结论：改造应基于现有抽象增量演进，而不是"推倒重建"。多用户路由架构已较完善，重点在存储外置和分布式状态化。

### 1.3 当前仍为本地状态的关键面
以下状态都需要纳入 UDS 迁移范围，否则无法真正无状态化：

| 子系统 | 当前实现 | 本地状态 | 多实例风险 |
|---|---|---|---|
| 会话历史 | `pkg/memory/jsonl.go` | `workspace/sessions/*.jsonl + *.meta.json` | 中 |
| 长期记忆 | `pkg/agent/memory.go` | `workspace/memory/MEMORY.md` 与日记文件 | 中 |
| Prompt/Bootstrap | `pkg/agent/context.go` | `AGENTS.md/SOUL.md/USER.md/IDENTITY.md` | 低 |
| Cron | `pkg/cron/service.go` | `workspace/cron/jobs.json` | **高**：重复执行 |
| 状态记录 | `pkg/state/state.go` | `workspace/state/state.json` | 中 |
| Heartbeat | `pkg/heartbeat/service.go` | `workspace/HEARTBEAT.md` 与 `heartbeat.log` | 低 |
| Media | `pkg/media/store.go` | 本地文件路径 + 进程内索引 | 中 |
| 消息总线 | `pkg/bus/bus.go` | 进程内 channel（固定缓冲 64 条） | 低（本期不改） |
| Provider 限流 | `pkg/providers/cooldown.go` | 进程内 `map[string]*cooldownEntry` | **高**：限流失效 |
| **OAuth 流程** | `web/backend/api/oauth.go` | `Handler.oauthFlows` 内存 Map | **严重**：认证失败 |
| **Gateway 进程** | `web/backend/api/gateway.go` | 全局变量 `gateway.cmd` + 无 PID 文件 | **严重**：端口冲突 |

#### 1.3.1 高风险项详解

**OAuth 流程状态（严重）**
- 当前：OAuth 流程状态存储在 `Handler.oauthFlows` 内存 Map
- 问题：多实例部署时，回调请求可能到达非发起流程的实例 → flow not found
- 解决：必须将 OAuth 流程状态持久化到 UDS KV

**Gateway 进程管理（严重）**
- 当前：Backend 内嵌进程管理，进程句柄存储在全局变量，无 PID 文件
- 问题：多实例可能同时启动多个 Gateway 进程 → 端口冲突
- 解决方案：
  1. Gateway 改为外部进程管理（systemd/Supervisor），Backend 仅监控状态
  2. 或：单 Gateway 实例 + 多 Backend 实例架构

**Provider 限流状态（高）**
- 当前：`CooldownTracker` 使用进程内 Map，每次启动新建
- 问题：进程重启后限流历史丢失；多实例间限流状态不同步
- 解决：迁移到 UDS KV，使用分布式状态存储

---

## 二、核心重构目标

### 2.1 目标
将 PicoClaw 改造成"计算无状态 + 状态外置"的分布式节点：
- 计算节点：AgentLoop、Tool 调度、路由判定
- 外置状态：会话、记忆、定时任务、运行态、限流态、技能资产
- 跨实例一致性：依赖 UDS KV / Model / Vector / Blob

### 2.2 非目标（本期不做）
- 不改写 `pkg/bus` 为外部 MQ（先保持进程内，后续按压测结论决策）
- 不重构全部 channel 协议实现，仅补齐多用户元数据与限流对接
- 不一次性清空所有本地回退逻辑，采用"灰度 + 双写 + 可回滚"

---

## 三、目标架构（修订）

### 3.1 存储与持久化层
- **UDS Model (PostgreSQL)**：会话元数据、bot 配置、用户关系、cron 任务定义
- **UDS KV**：短时运行态（placeholder/typing）、分布式锁、限流计数、队列游标、OAuth 流程状态
- **UDS Vector**：长期记忆向量检索（替代 `MEMORY.md` 的核心能力）
- **UDS Blob**：Prompt 模板、Identity、技能包与静态资产

### 3.2 任务与调度层
- 保留 cron 语义，拆分为"扫描器 + 执行器"
- 扫描器负责触发判定与投递任务
- 执行器从 UDS 队列消费并执行
- 分布式互斥使用 KV 锁（`SetNX`）
- **必须保留**现有安全约束：命令型 cron 仅 internal channel 且 `command_confirm=true`

### 3.3 多用户与安全策略层
- 入站元数据规范化：统一补齐 `account_id`，并兼容 `team_id/guild_id/parent_peer`
- 路由继续沿用现有七级优先级体系，新增 user-aware 策略
- Tool 安全分层：
  - RBAC：按 AccountID/user role 控制高危工具可见性
  - 既有护栏保留：exec deny-pattern、路径沙箱、remote 开关、spawn allowlist

### 3.4 控制平面层（必须纳入，改造难度高）
- `web/backend` 作为 control-plane 一并改造：
  - 会话 API 改为读 UDS
  - Gateway 状态管理与事件广播支持多实例
  - OAuth flow 状态落盘到 UDS KV（**优先级 P0**）
  - Gateway 进程管理改为外部托管或单实例架构（**优先级 P0**）

#### 3.4.1 Gateway 架构选择

| 方案 | 优点 | 缺点 | 推荐场景 |
|------|------|------|---------|
| 外部进程管理 | 解耦彻底，Backend 无状态 | 需运维配合 | 生产环境 |
| 单 Gateway + 多 Backend | 改动小，兼容现有架构 | Gateway 单点 | 中小规模 |
| Gateway 主备选举 | 高可用 | 复杂度高 | 大规模生产 |

### 3.5 上游同步策略
- 不侵入大块改写 `pkg/agent/loop.go` 与 `pkg/bus`
- 新增 `pkg/storage/uds/`（或 `pkg/uds_adapter/`）承载 UDS 适配实现
- 在 `cmd/picoclaw/internal/gateway/helpers.go` 与 `pkg/agent/instance.go` 完成注入

---

## 四、关键差异修正（相对 v1.0）

1. **入口修正**：改造注入点从"只改 `main.go`"修正为 gateway/agent helper + agent instance。
2. **抽象修正**：`SessionStore` 已存在，本期做"接口扩展和 UDS 实现"，不是重复定义。
3. **安全修正**：RBAC 依赖 `account_id`，需先完成各 channel 元数据补齐与统一映射。
4. **范围修正**：新增 state/heartbeat/media/web backend 的迁移任务。
5. **兼容修正**：必须保留现有 cron/exec/spawn 安全防线，不可因重写丢失。
6. **能力认知修正**：providers 现有 fallback/cooldown 已可复用，重点是"分布式状态化"。
7. **风险认知修正**：OAuth/Gateway 改造是**严重阻塞点**，需提前规划。

---

## 五、实施路线（4 个 Sprint）

### Sprint 0：基线与抽象收敛（3-4 天）
**目标**：先把"现有能力"和"迁移边界"冻结，避免返工。
- [ ] 固化现状清单：会话、记忆、cron、state、heartbeat、media、web backend
- [ ] 固化安全护栏清单：30+ deny-pattern、路径沙箱、command confirm、spawn allowlist
- [ ] 设计统一存储端口（复用现有 SessionStore/Store，补充 PromptLoader/StateStore 等）
- [ ] 定义多用户元数据规范：`account_id/team_id/guild_id/parent_peer`
- [ ] 确定 Gateway 架构方案（外部托管 vs 单实例）
- [ ] 输出迁移验收基线（功能不回退、性能指标、回滚策略）

### Sprint 1：存储外置（会话/Prompt/记忆）(Week 1)
**目标**：核心对话链路可在 UDS 上运行。
- [ ] 在 `pkg/storage/uds/` 实现会话与摘要存储（替换本地 JSONL 主路径）
- [ ] `ContextBuilder` 增加远端 Prompt/Identity 加载策略（保留本地回退）
- [ ] 长期记忆从 `MEMORY.md` 升级到 Vector 检索，支持灰度开关
- [ ] 打通单会话链路回归（含工具调用、摘要、历史压缩）
- [ ] **OAuth 流程状态持久化到 UDS KV**（提前处理严重风险）

### Sprint 2：多用户路由与安全策略 (Week 2)
**目标**：权限和隔离逻辑可在多通道稳定生效。
- [ ] 各 channel 入站 metadata 统一补齐 `account_id`
- [ ] 路由保持现有 cascade，扩展 user-aware 策略配置
- [ ] 实现 RBAC Tool 过滤（⚠️ 时间可能不足，可拆分为独立 Sprint）
- [ ] 保留并回归验证 exec/cron/spawn 原有安全限制
- [ ] **Gateway 进程管理改造**（按 Sprint 0 确定的方案执行）

### Sprint 3：分布式调度与流控 + 控制平面改造 (Week 3)
**目标**：单点状态迁移到分布式状态。
- [ ] 重构 `pkg/cron/service.go` 为"扫描+投递+执行"分离架构
- [ ] 使用 UDS KV 锁避免跨实例重复执行
- [ ] providers 限流状态迁移到 UDS KV（替换进程内 cooldown 主路径）
- [ ] web/backend 的 sessions、events 接入共享存储
- [ ] SSE 事件广播支持多实例（可选：Redis Pub/Sub）

### Sprint 4：云原生部署与压测收敛 (Week 4)
**目标**：多副本稳定运行并可回滚。
- [ ] 交付 Dockerfile 与 K8s YAML（最小化卷依赖）
- [ ] 压测 100→500→1000 并发，逐步验证会话一致性、调度幂等、故障恢复
- [ ] 完成灰度发布与回滚演练（本地存储回退开关）

---

## 六、代码改造落点（必改文件）

### 6.1 Runtime 注入与组装
- `cmd/picoclaw/internal/gateway/helpers.go`（高复杂度）
- `cmd/picoclaw/internal/agent/helpers.go`
- `pkg/agent/instance.go`（高复杂度）

### 6.2 Agent 关键链路
- `pkg/agent/context.go`
- `pkg/agent/memory.go`
- `pkg/agent/loop.go`（仅最小侵入式接线）

### 6.3 存储与调度
- `pkg/session/*`、`pkg/memory/*`
- `pkg/cron/service.go`（高复杂度）
- `pkg/providers/cooldown.go`（分布式限流状态）
- `pkg/state/state.go`（状态存储迁移）

### 6.4 多用户与渠道
- `pkg/channels/*`（metadata 规范化，逐一改造）
- `pkg/routing/*`（保留现有优先级，新增多用户策略参数）

### 6.5 控制平面（改动难度高）
- `web/backend/api/session.go`
- `web/backend/api/gateway.go`（极高复杂度）
- `web/backend/api/oauth.go`（极高复杂度）
- `web/backend/api/models.go`
- `web/backend/api/events.go`（SSE 多实例支持）

### 6.6 遗漏的必改文件
- `pkg/heartbeat/service.go`（HEARTBEAT.md 外置）
- `pkg/media/store.go`（Blob 存储适配）

---

## 七、数据模型建议（UDS）

### 7.1 Model 表（示例）
- `bot_configs`：bot 基础配置、启用技能、Prompt 版本
- `user_accounts`：用户与账号映射
- `session_meta`：会话摘要、更新时间、用户归属
- `cron_jobs`：任务定义、下次触发时间、状态

### 7.2 KV Key 规范（示例）
- `rl:{provider}:cooldown`：Provider 冷却状态
- `rl:{provider}:error_count`：错误计数
- `rl:{user}:{provider}:{window}`：用户级限流桶
- `lock:cron:{job_id}`：cron 分布式锁
- `rt:{channel}:{chat_id}:placeholder`：临时会话态
- `oauth:flow:{flow_id}`：OAuth 流程状态

### 7.3 Blob/Vector
- `blob://prompts/{bot_id}/{version}`
- `vector://memory/{user}/{agent}`

---

## 八、验收标准（Done Definition）

- [ ] **功能等价**：现有主链路（对话/tool/summary/cron）无行为回退
- [ ] **安全等价**：exec/cron/spawn 现有限制全部保留
  - 30+ deny-pattern 生效
  - 路径沙箱 `restrict_to_workspace` 正常
  - Cron 命令需 `internal channel` + `command_confirm=true`
  - Spawn 受 `allow_agents` 白名单控制
- [ ] **隔离正确**：跨用户会话和配置不可串读串写
- [ ] **分布式正确**：
  - cron 不重放
  - 限流状态跨实例一致
  - OAuth 流程多实例可用
- [ ] **管理面可用**：web backend 核心 API 在多实例下可工作
- [ ] **可回滚**：开关可切回本地存储路径

---

## 九、Git 与分支协作规范（沿用，补充入口冲突点）

### 9.1 分支模型
- `main`：仅同步 upstream，禁止业务定制提交
- `wmnn`：WMNN 长效基线
- 短分支：`feat/*`、`fix/*`、`docs/*`，统一从 `wmnn` 切出

### 9.2 合并策略
1. `feat/*` -> PR -> `wmnn`
2. commit message 使用 Angular 前缀
3. 优先 squash merge 保持历史整洁

### 9.3 上游同步
1. `main` 同步 upstream
2. `wmnn` 执行 `rebase main`
3. 重点冲突点不再假设"仅 main.go"，实际多集中于：
   - `cmd/picoclaw/internal/gateway/helpers.go`
   - `pkg/agent/instance.go`
   - `web/backend/api/*`
