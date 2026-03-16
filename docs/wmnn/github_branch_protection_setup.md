# GitHub 分支保护规则配置指南

本文档提供在 GitHub 上配置分支保护规则的详细步骤。

## 前提条件

- 你需要有仓库的 **Admin** 权限
- 仓库地址: `https://github.com/sipeed/picoclaw`

## 配置步骤

### 1. 进入分支保护设置

1. 打开仓库: https://github.com/sipeed/picoclaw
2. 点击 **Settings** (设置)
3. 在左侧菜单中点击 **Branches** (分支)
4. 找到 **Branch protection rules** (分支保护规则) 部分

### 2. 配置 `main` 分支保护

点击 **Add rule** (添加规则) 或编辑现有的 `main` 规则：

#### Branch name pattern (分支名称模式)
```
main
```

#### 必须启用的选项

**Protect matching branches** (保护匹配的分支):

- ✅ **Require a pull request before merging** (合并前需要 Pull Request)
  - ✅ **Require approvals** (需要审批)
    - 设置 **Required number of approvals before merging**: `1` (至少 1 个审批)
  - ✅ **Dismiss stale pull request approvals when new commits are pushed** (新提交时取消旧审批)
  - ✅ **Require review from Code Owners** (需要代码所有者审查) - 可选

- ✅ **Require status checks to pass before merging** (合并前需要通过状态检查)
  - ✅ **Require branches to be up to date before merging** (合并前需要更新分支)
  - 添加必需的状态检查（如果有 CI/CD）:
    - `build`
    - `test`
    - `lint`

- ✅ **Require conversation resolution before merging** (合并前需要解决所有对话)

- ✅ **Require signed commits** (需要签名提交) - 可选，推荐

- ✅ **Require linear history** (需要线性历史) - 可选

- ✅ **Include administrators** (包括管理员)
  - ⚠️ **重要**: 启用此选项确保管理员也遵守规则

- ✅ **Restrict who can push to matching branches** (限制谁可以推送到匹配的分支)
  - **不要添加任何人或团队** - 这样就完全禁止直接推送

- ✅ **Allow force pushes** (允许强制推送)
  - ❌ **不要启用** - 保持禁用状态

- ✅ **Allow deletions** (允许删除)
  - ❌ **不要启用** - 保持禁用状态

点击 **Create** 或 **Save changes** 保存规则。

### 3. 配置 `wmnn` 分支保护

点击 **Add rule** (添加规则) 或编辑现有的 `wmnn` 规则：

#### Branch name pattern (分支名称模式)
```
wmnn
```

#### 必须启用的选项

**Protect matching branches** (保护匹配的分支):

- ✅ **Require a pull request before merging** (合并前需要 Pull Request)
  - ❌ **不启用** - wmnn 分支通过直接合并 main 更新

- ✅ **Require status checks to pass before merging** (合并前需要通过状态检查)
  - ✅ **Require branches to be up to date before merging** (合并前需要更新分支)

- ✅ **Include administrators** (包括管理员)

- ✅ **Restrict who can push to matching branches** (限制谁可以推送到匹配的分支)
  - **添加特定用户或团队**:
    - 只添加负责维护 wmnn 分支的管理员
    - 例如: `@leoobai` 或特定的维护团队

- ✅ **Restrict who can merge pull requests** (限制谁可以合并 PR)
  - 添加相同的用户或团队

- ✅ **Allow force pushes** (允许强制推送)
  - ❌ **不要启用** - 保持禁用状态

- ✅ **Allow deletions** (允许删除)
  - ❌ **不要启用** - 保持禁用状态

点击 **Create** 或 **Save changes** 保存规则。

## 配置截图参考

### main 分支配置示例

```
Branch name pattern: main

☑ Require a pull request before merging
  ☑ Require approvals (1)
  ☑ Dismiss stale pull request approvals when new commits are pushed

☑ Require status checks to pass before merging
  ☑ Require branches to be up to date before merging

☑ Require conversation resolution before merging

☑ Include administrators

☑ Restrict who can push to matching branches
  (No users or teams selected - 完全禁止直接推送)

☐ Allow force pushes (保持未选中)
☐ Allow deletions (保持未选中)
```

### wmnn 分支配置示例

```
Branch name pattern: wmnn

☐ Require a pull request before merging (不启用)

☑ Require status checks to pass before merging
  ☑ Require branches to be up to date before merging

☑ Include administrators

☑ Restrict who can push to matching branches
  Users/Teams: @leoobai (或维护团队)

☐ Allow force pushes (保持未选中)
☐ Allow deletions (保持未选中)
```

## 验证配置

配置完成后，验证规则是否生效：

### 测试 1: 尝试直接推送到 main

```bash
git checkout main
echo "test" >> test.txt
git add test.txt
git commit -m "test"
git push origin main
```

**预期结果**: GitHub 拒绝推送，显示类似错误：
```
remote: error: GH006: Protected branch update failed for refs/heads/main.
remote: error: Changes must be made through a pull request.
```

### 测试 2: 通过 PR 合并到 main

1. 创建功能分支并推送
2. 在 GitHub 上创建 PR
3. 等待审批和状态检查通过
4. 合并 PR

**预期结果**: ✅ 成功合并

### 测试 3: 从 main 合并到 wmnn

```bash
git checkout wmnn
git merge main
git push origin wmnn
```

**预期结果**:
- 如果你是授权用户: ✅ 成功推送
- 如果你不是授权用户: ❌ GitHub 拒绝推送

## 额外的 GitHub 设置建议

### 1. 启用 Required Reviews

在 **Settings → Branches** 中，为 main 分支：
- 设置至少 1 个审批者
- 启用 "Dismiss stale pull request approvals when new commits are pushed"

### 2. 配置 CODEOWNERS 文件

创建 `.github/CODEOWNERS` 文件：

```
# 默认所有文件需要核心团队审查
* @sipeed/picoclaw-core

# 特定目录的所有者
/pkg/providers/ @sipeed/provider-maintainers
/pkg/channels/ @sipeed/channel-maintainers
/web/ @sipeed/frontend-team
/docs/ @sipeed/documentation-team

# wmnn 相关文档
/docs/wmnn/ @leoobai
```

### 3. 配置 Branch Protection 通知

在 **Settings → Notifications** 中：
- 启用分支保护规则变更通知
- 确保团队成员收到相关通知

### 4. 设置 Merge 策略

在 **Settings → General → Pull Requests** 中：
- ✅ **Allow merge commits** (允许合并提交)
- ✅ **Allow squash merging** (允许压缩合并)
- ❌ **Allow rebase merging** (禁用变基合并) - 可选

推荐设置：
- **Default to squash merging** (默认使用压缩合并)

## 常见问题

### Q: 管理员可以绕过这些规则吗？

A: 如果启用了 "Include administrators"，管理员也必须遵守规则。但管理员可以在紧急情况下临时禁用规则。

### Q: 如何处理紧急修复？

A:
1. 创建 hotfix 分支
2. 快速创建 PR
3. 请求紧急审查
4. 合并后立即同步到 wmnn

### Q: 如果配置错误怎么办？

A: 管理员可以随时编辑或删除分支保护规则，不会影响现有代码。

### Q: 这些规则会影响 CI/CD 吗？

A: 不会。CI/CD 使用的 GitHub Actions 或其他服务账号可以配置为绕过某些限制。

## 验证清单

配置完成后，检查以下项目：

- [ ] main 分支已配置保护规则
- [ ] wmnn 分支已配置保护规则
- [ ] 禁止直接推送到 main
- [ ] 禁止未授权推送到 wmnn
- [ ] PR 需要审批才能合并到 main
- [ ] 管理员也受规则约束
- [ ] 测试推送被正确拒绝
- [ ] 测试 PR 流程正常工作
- [ ] 团队成员已收到通知

## 相关文档

- [GitHub Branch Protection Documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- [本地 Git Hooks 配置](git_branch_management.md)
- [贡献指南](../../CONTRIBUTING.md)

---

**创建日期**: 2026-03-16
**维护者**: PicoClaw Team
