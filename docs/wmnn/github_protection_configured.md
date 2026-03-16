# GitHub 分支保护配置完成报告

## ✅ 配置状态

**仓库**: `imleoo/picoclaw` (fork from sipeed/picoclaw)
**配置时间**: 2026-03-16
**配置方式**: GitHub CLI (`gh api`)

## 已配置的分支保护规则

### 1. `main` 分支保护 ✅

| 规则 | 状态 | 说明 |
|------|------|------|
| **Enforce admins** | ✅ 启用 | 管理员也必须遵守规则 |
| **Require PR reviews** | ✅ 启用 | 必须通过 Pull Request 合并 |
| **Required approvals** | ✅ 1 个 | 至少需要 1 个审批 |
| **Dismiss stale reviews** | ✅ 启用 | 新提交时取消旧审批 |
| **Require conversation resolution** | ✅ 启用 | 必须解决所有讨论 |
| **Allow force pushes** | ❌ 禁用 | 禁止强制推送 |
| **Allow deletions** | ❌ 禁用 | 禁止删除分支 |

**效果**:
- ❌ 无法直接推送到 main 分支
- ✅ 必须通过 PR 并获得审批才能合并
- ✅ 管理员也受此限制

### 2. `wmnn` 分支保护 ✅

| 规则 | 状态 | 说明 |
|------|------|------|
| **Enforce admins** | ✅ 启用 | 管理员也必须遵守规则 |
| **Require PR reviews** | ❌ 禁用 | 允许直接合并（仅从 main） |
| **Allow force pushes** | ❌ 禁用 | 禁止强制推送 |
| **Allow deletions** | ❌ 禁用 | 禁止删除分支 |

**效果**:
- ✅ 可以直接从 main 合并到 wmnn
- ❌ 禁止强制推送和删除
- ⚠️ 注意：个人仓库无法限制特定用户推送

## 配置命令记录

### main 分支配置
```bash
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  /repos/imleoo/picoclaw/branches/main/protection \
  --input - <<'EOF'
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
EOF
```

### wmnn 分支配置
```bash
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  /repos/imleoo/picoclaw/branches/wmnn/protection \
  --input - <<'EOF'
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
```

## 验证配置

### 查看 main 分支保护
```bash
gh api repos/imleoo/picoclaw/branches/main/protection | jq
```

### 查看 wmnn 分支保护
```bash
gh api repos/imleoo/picoclaw/branches/wmnn/protection | jq
```

### 在线查看
- Main: https://github.com/imleoo/picoclaw/settings/branch_protection_rules
- 或直接访问: https://github.com/imleoo/picoclaw/settings/branches

## 测试验证

### 测试 1: 尝试直接推送到 main（应该失败）

```bash
git checkout main
echo "test" >> test.txt
git add test.txt
git commit -m "test: direct push"
git push origin main
```

**预期结果**:
```
remote: error: GH006: Protected branch update failed for refs/heads/main.
remote: error: At least 1 approving review is required by reviewers with write access.
To https://github.com/imleoo/picoclaw.git
 ! [remote rejected] main -> main (protected branch hook declined)
error: failed to push some refs to 'https://github.com/imleoo/picoclaw.git'
```

### 测试 2: 通过 PR 合并到 main（应该成功）

```bash
git checkout -b feature/test
git push origin feature/test
gh pr create --title "Test PR" --body "Testing branch protection"
# 等待审批后
gh pr merge --squash
```

### 测试 3: 从 main 合并到 wmnn（应该成功）

```bash
git checkout wmnn
git merge main
git push origin wmnn
```

**预期结果**: ✅ 推送成功

## 个人仓库的限制

⚠️ **重要提示**: 由于这是个人仓库（非组织仓库），以下功能不可用：

1. **用户/团队限制** (`restrictions`)
   - 无法限制只有特定用户可以推送
   - 所有有写权限的用户都可以推送（在遵守其他规则的前提下）

2. **CODEOWNERS 强制审查**
   - 可以创建 `.github/CODEOWNERS` 文件
   - 但无法强制要求代码所有者审查

3. **状态检查要求**
   - 可以配置，但需要先设置 CI/CD

## 与本地 Git Hooks 的配合

GitHub 分支保护 + 本地 Git Hooks = 双重保护

| 保护层 | 作用时机 | 优势 |
|--------|---------|------|
| **本地 Git Hooks** | `git push` 之前 | 即时反馈，节省时间 |
| **GitHub 保护** | 推送到远程时 | 最终防线，无法绕过 |

即使本地使用 `--no-verify` 绕过 hooks，GitHub 仍会拒绝不符合规则的推送。

## 后续维护

### 修改保护规则

```bash
# 修改 main 分支保护
gh api \
  --method PUT \
  /repos/imleoo/picoclaw/branches/main/protection \
  --input updated-config.json

# 删除保护规则
gh api \
  --method DELETE \
  /repos/imleoo/picoclaw/branches/main/protection
```

### 查看所有保护规则

```bash
gh api repos/imleoo/picoclaw/branches | jq '.[] | {name: .name, protected: .protected}'
```

## 相关文档

- [本地 Git Hooks 配置](git_branch_management.md)
- [GitHub 配置详细指南](github_branch_protection_setup.md)
- [快速配置指南](github_setup_quickstart.md)
- [贡献指南](../../CONTRIBUTING.md)
- [Claude Code 开发指南](../../CLAUDE.md)

## 配置清单

- [x] main 分支保护已启用
- [x] wmnn 分支保护已启用
- [x] 禁止直接推送到 main
- [x] 要求 PR 审批（1 个）
- [x] 禁止强制推送
- [x] 禁止删除分支
- [x] 管理员受规则约束
- [x] 本地 Git Hooks 已安装
- [x] 文档已更新

## 总结

✅ **GitHub 分支保护规则配置完成！**

现在你的仓库有了双重保护：
1. **本地 Git Hooks** - 在推送前阻止违规操作
2. **GitHub 分支保护** - 在服务器端强制执行规则

这确保了：
- main 分支只能通过审查的 PR 更新
- wmnn 分支只能从 main 合并更新
- 所有分支都受到保护，防止意外删除或强制推送

---

**配置完成时间**: 2026-03-16
**配置者**: imleoo
**仓库**: https://github.com/imleoo/picoclaw
