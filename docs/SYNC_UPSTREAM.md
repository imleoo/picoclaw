# 上游同步自动化

自动同步 `sipeed/picoclaw:main` → `imleoo/picoclaw:main` → `imleoo/picoclaw:wmnn` 的 GitHub Actions 工作流。

## 工作流程

```
sipeed/picoclaw:main (上游)
         ↓ (自动检测更新)
imleoo/picoclaw:main (fork main)
         ↓ (自动合并)
imleoo/picoclaw:wmnn (开发分支)
```

**单向流动保护**：
- ✅ 允许：upstream → main → wmnn
- ❌ 禁止：wmnn → main (反向同步)
- ❌ 禁止：main → upstream (推送到上游)

## 自动触发

### 定时同步
- **时间**：每天 UTC 02:00 (北京时间 10:00)
- **检查**：自动检测上游是否有新提交
- **执行**：有更新时自动创建 PR 并同步

### 手动触发
在 GitHub Actions 页面手动运行：
1. 进入 **Actions** → **Sync Upstream**
2. 点击 **Run workflow**
3. 可选：勾选 `force_sync` 强制同步（即使没有更新）

## 同步流程

### 阶段 1: 同步上游到 main

1. **检测更新**：对比 `sipeed/picoclaw:main` 和 `imleoo/picoclaw:main`
2. **创建分支**：`sync/upstream-YYYYMMDD-HHMMSS`
3. **合并提交**：将上游更新合并到同步分支
4. **创建 PR**：自动创建 PR 到 main 分支
5. **等待审核**：需要人工审核和合并 PR

### 阶段 2: 同步 main 到 wmnn

1. **等待 PR 合并**：监控阶段 1 的 PR 状态（最多等待 30 分钟）
2. **自动合并**：PR 合并后，自动将 main 合并到 wmnn
3. **直接推送**：wmnn 分支允许从 main 合并，无需 PR

## 配置选项

### 可选：自动批准和合并

如果你想完全自动化（不需要手动审核），可以配置：

#### 1. 创建 Personal Access Token (PAT)

1. GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. 生成新 token，权限：`repo` (完整仓库访问)
3. 复制 token

#### 2. 添加仓库 Secrets

在仓库 Settings → Secrets and variables → Actions：
- 添加 `PAT_TOKEN`：粘贴你的 PAT

#### 3. 添加仓库 Variables

在仓库 Settings → Secrets and variables → Actions → Variables：
- 添加 `AUTO_APPROVE_SYNC`：值为 `true`（启用自动批准）
- 添加 `AUTO_MERGE_SYNC`：值为 `true`（启用自动合并）

**注意**：
- 自动批准需要 PAT，因为 GitHub Actions 不能批准自己创建的 PR
- 自动合并需要仓库有合并权限
- 如果有分支保护规则要求审核，需要使用管理员权限

### 可选：调整同步时间

编辑 `.github/workflows/sync-upstream.yml`：

```yaml
on:
  schedule:
    # 修改这里的 cron 表达式
    - cron: '0 2 * * *'  # UTC 02:00 = 北京时间 10:00
```

Cron 表达式示例：
- `0 2 * * *` - 每天 02:00 UTC
- `0 */6 * * *` - 每 6 小时一次
- `0 0 * * 1` - 每周一 00:00 UTC

## 防止反向同步

工作流包含保护机制，防止意外的反向同步：

### Git Hooks 保护
本地 Git hooks (`.git/hooks/pre-push`) 会阻止：
- 直接推送到 main 分支
- 直接推送到 wmnn 分支（除非从 main 合并）

### GitHub Actions 保护
PR 检查会阻止：
- wmnn → main 的 PR
- 任何推送到 upstream 的尝试

## 监控和通知

### 查看同步状态
1. GitHub Actions 页面查看工作流运行历史
2. 检查自动创建的 PR（标签：`sync`, `automated`）

### 失败处理
如果同步失败：
1. 查看 Actions 日志了解失败原因
2. 常见问题：
   - **合并冲突**：需要手动解决冲突
   - **PR 未合并**：阶段 2 会等待 30 分钟后超时
   - **权限问题**：检查 GITHUB_TOKEN 权限

### 手动干预
如果需要手动同步：

```bash
# 同步上游到 main
git checkout main
git fetch upstream
git merge upstream/main
# 创建 PR 或使用管理员权限推送

# 同步 main 到 wmnn
git checkout wmnn
git merge main
git push origin wmnn
```

## 最佳实践

1. **定期检查**：每周查看一次自动同步的 PR
2. **及时审核**：尽快审核和合并同步 PR，避免积累太多更新
3. **冲突处理**：遇到合并冲突时，优先保留上游的更改
4. **测试验证**：重要更新合并后，在 wmnn 分支进行测试
5. **保持清洁**：不要在 main 分支进行开发，所有开发在 wmnn 或 feature 分支

## 故障排查

### PR 创建失败
- 检查 GITHUB_TOKEN 是否有 `contents: write` 和 `pull-requests: write` 权限
- 确认没有同名的分支或 PR 存在

### 自动合并失败
- 检查分支保护规则是否允许管理员强制合并
- 确认 CI 检查是否全部通过
- 验证 PAT_TOKEN 是否有效（如果配置了自动批准）

### wmnn 同步失败
- 检查 wmnn 分支是否有未推送的本地提交
- 确认没有合并冲突
- 验证 Git hooks 是否正确安装

## 相关文档

- [分支保护规则](../scripts/install-git-hooks.sh)
- [开发工作流](../CLAUDE.md#development-workflow)
- [GitHub Actions 文档](https://docs.github.com/en/actions)
