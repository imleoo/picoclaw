# PicoClaw Docker 部署指南

## 配置说明

已为你配置好 zhiguofan API 供应商。

### 配置文件位置

- **环境变量**: `docker/.env`
- **配置文件**: `docker/data/config.json`
- **Docker Compose**: `docker/docker-compose.yml`

### 当前配置

**API 供应商**: zhiguofan
**API Base URL**: https://openclaw.zhiguo.fan/v1
**模型**: gpt-4o
**模型名称**: zhiguofan-gpt

## 使用方法

### 1. Agent 模式（单次查询）

从 `docker/` 目录运行：

```bash
cd docker
docker compose run --rm picoclaw-agent -m "你的问题"
```

示例：
```bash
docker compose run --rm picoclaw-agent -m "你好，请做个自我介绍"
```

### 2. Gateway 模式（长期运行的机器人）

启动服务：
```bash
cd docker
docker compose --profile gateway up
```

后台运行：
```bash
docker compose --profile gateway up -d
```

停止服务：
```bash
docker compose --profile gateway down
```

### 3. Launcher 模式（Web 控制台 + Gateway）

启动 Web 控制台：
```bash
cd docker
docker compose --profile launcher up
```

访问地址：
- Web 控制台: http://127.0.0.1:18800
- Gateway API: http://127.0.0.1:18790

## 故障排查

### API 502 错误

如果遇到 "Upstream service temporarily unavailable" 错误，说明 API 服务暂时不可用。请：

1. 检查 API 服务状态
2. 确认 API Key 是否有效
3. 稍后重试

### 配置验证

检查配置是否正确加载：
```bash
docker run --rm --user root \
  -v "$(pwd)/data:/root/.picoclaw:rw" \
  --env-file .env \
  docker.io/sipeed/picoclaw:latest \
  agent --debug -m "测试"
```

### 查看日志

```bash
# Gateway 模式日志
docker compose --profile gateway logs -f

# Launcher 模式日志
docker compose --profile launcher logs -f
```

## 配置修改

### 修改模型

编辑 `docker/data/config.json`：

```json
{
  "agents": {
    "defaults": {
      "model_name": "你的模型名称"
    }
  },
  "model_list": [
    {
      "model_name": "你的模型名称",
      "model": "openai/gpt-4o",
      "api_key": "你的API密钥",
      "api_base": "https://你的API地址/v1"
    }
  ]
}
```

### 添加消息渠道

在 `config.json` 中添加 `channels` 配置，例如 Telegram：

```json
{
  "channels": {
    "telegram": {
      "enabled": true,
      "token": "你的Telegram Bot Token"
    }
  }
}
```

支持的渠道：telegram, discord, slack, feishu, wecom 等。

## 数据持久化

所有数据存储在 `docker/data/` 目录：
- `config.json` - 配置文件
- `picoclaw.db` - 会话数据库（运行后自动创建）
- `workspace/` - 工作空间文件（运行后自动创建）

## 注意事项

1. 首次运行会自动创建必要的目录和文件
2. 配置文件修改后需要重启容器才能生效
3. API Key 等敏感信息请妥善保管
4. 建议使用 Gateway 或 Launcher 模式进行长期运行
