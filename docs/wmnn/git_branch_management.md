# Git 分支管理规范

本项目实施严格的分支保护策略，通过 Git hooks 自动执行。

## 分支保护规则

### 1. 禁止直接推送到 `main` 分支 ❌

**规则**: 不允许任何直接推送到 `main` 分支的操作。

**原因**: 保护主分支稳定性，所有变更必须经过代码审查。

**正确流程**:
```bash
# 创建功能分支
git checkout -b feature/your-feature

# 开发并提交
git add .
git commit -m "feat: add new feature"

# 推送功能分支
git push origin feature/your-feature

# 在 GitHub 上创建 Pull Request
```

### 2. 禁止直接推送到 `wmnn` 分支 ❌

**规则**: 不允许任何直接提交或推送到 `wmnn` 分支。

**原因**: `wmnn` 分支仅用于接收来自 `main` 分支的合并。

### 3. 仅允许从 `main` 合并到 `wmnn` ✅

**规则**: `wmnn` 分支只能通过合并 `main` 分支来更新。

**正确流程**:
```bash
# 切换到 wmnn 分支
git checkout wmnn

# 确保本地是最新的
git pull origin wmnn

# 合并 main 分支
git merge main

# 推送合并结果
git push origin wmnn
```

## 安装 Git Hooks

克隆仓库后，必须安装 Git hooks 以启用分支保护：

```bash
./scripts/install-git-hooks.sh
```

安装成功后会看到：
```
✅ Git hooks installed successfully!

Branch protection rules:
  1. ❌ Direct push to 'main' branch is prohibited
  2. ❌ Direct push to 'wmnn' branch is prohibited
  3. ✅ Only merges from 'main' to 'wmnn' are allowed
```

## 错误示例与解决方案

### 错误 1: 尝试直接推送到 main

```bash
$ git push origin main
❌ ERROR: Direct push to 'main' branch is prohibited!

Please use Pull Requests to merge changes into main.

Workflow:
  1. Create a feature branch: git checkout -b feature/your-feature
  2. Push your branch: git push origin feature/your-feature
  3. Create a Pull Request on GitHub
```

**解决方案**: 创建功能分支并通过 PR 合并。

### 错误 2: 尝试直接推送到 wmnn

```bash
$ git push origin wmnn
❌ ERROR: Direct push to 'wmnn' branch is prohibited!

Only merges from 'main' branch are allowed.

Correct workflow:
  1. git checkout wmnn
  2. git merge main
  3. git push origin wmnn
```

**解决方案**: 使用 `git merge main` 而不是直接提交。

### 错误 3: 从非 main 分支合并到 wmnn

```bash
$ git checkout wmnn
$ git merge feature/my-feature
$ git push origin wmnn
❌ ERROR: Can only merge from 'main' branch to 'wmnn' branch!

Current operation is not a merge from main.

Correct workflow:
  1. git checkout wmnn
  2. git merge main
  3. git push origin wmnn
```

**解决方案**: 先将功能分支合并到 main（通过 PR），然后再从 main 合并到 wmnn。

## 分支工作流程图

```
feature/xxx ──PR──> main ──merge──> wmnn
     │               │                │
     │               │                │
  开发分支        主分支          WMNN 分支
  (可推送)      (仅 PR)         (仅从 main 合并)
```

## 紧急情况绕过 Hooks

**⚠️ 警告**: 仅在紧急情况下使用，需要团队负责人批准。

```bash
git push --no-verify origin <branch>
```

绕过 hooks 后，必须在事后说明原因并记录在提交信息中。

## 常见问题

**Q: 为什么需要这些规则？**
A: 保护关键分支稳定性，确保代码质量，防止意外的直接提交。

**Q: 如果我忘记安装 hooks 会怎样？**
A: 本地不会有保护，但 GitHub 的分支保护规则仍会阻止不符合规范的推送。

**Q: 我可以删除 hooks 吗？**
A: 技术上可以，但强烈不建议。这会破坏团队的代码管理流程。

**Q: wmnn 分支的用途是什么？**
A: wmnn 是一个特殊的集成分支，用于特定的部署或测试环境，只接收经过验证的 main 分支代码。

## 相关文档

- [CONTRIBUTING.md](../CONTRIBUTING.md) - 贡献指南
- [CLAUDE.md](../CLAUDE.md) - Claude Code 开发指南
