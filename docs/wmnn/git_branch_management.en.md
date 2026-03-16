# Git Branch Management Rules

This document is also available in [中文](git_branch_management.md).

## Branch Protection Rules

This repository enforces strict branch protection via Git hooks:

### 1. Prohibit Direct Push to `main` Branch ❌

**Rule**: No direct pushes to the `main` branch are allowed.

**Reason**: Protect main branch stability; all changes must go through code review.

**Correct Workflow**:
```bash
# Create feature branch
git checkout -b feature/your-feature

# Develop and commit
git add .
git commit -m "feat: add new feature"

# Push feature branch
git push origin feature/your-feature

# Create Pull Request on GitHub
```

### 2. Prohibit Direct Push to `wmnn` Branch ❌

**Rule**: No direct commits or pushes to the `wmnn` branch are allowed.

**Reason**: The `wmnn` branch only receives merges from the `main` branch.

### 3. Only Allow Merges from `main` to `wmnn` ✅

**Rule**: The `wmnn` branch can only be updated by merging from `main`.

**Correct Workflow**:
```bash
# Switch to wmnn branch
git checkout wmnn

# Ensure local is up-to-date
git pull origin wmnn

# Merge main branch
git merge main

# Push merge result
git push origin wmnn
```

## Installing Git Hooks

After cloning the repository, you must install Git hooks to enable branch protection:

```bash
./scripts/install-git-hooks.sh
```

After successful installation, you'll see:
```
✅ Git hooks installed successfully!

Branch protection rules:
  1. ❌ Direct push to 'main' branch is prohibited
  2. ❌ Direct push to 'wmnn' branch is prohibited
  3. ✅ Only merges from 'main' to 'wmnn' are allowed
```

## Error Examples and Solutions

### Error 1: Attempting Direct Push to main

```bash
$ git push origin main
❌ ERROR: Direct push to 'main' branch is prohibited!

Please use Pull Requests to merge changes into main.

Workflow:
  1. Create a feature branch: git checkout -b feature/your-feature
  2. Push your branch: git push origin feature/your-feature
  3. Create a Pull Request on GitHub
```

**Solution**: Create a feature branch and merge via PR.

### Error 2: Attempting Direct Push to wmnn

```bash
$ git push origin wmnn
❌ ERROR: Direct push to 'wmnn' branch is prohibited!

Only merges from 'main' branch are allowed.

Correct workflow:
  1. git checkout wmnn
  2. git merge main
  3. git push origin wmnn
```

**Solution**: Use `git merge main` instead of direct commits.

### Error 3: Merging from Non-main Branch to wmnn

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

**Solution**: First merge feature branch to main (via PR), then merge from main to wmnn.

## Branch Workflow Diagram

```
feature/xxx ──PR──> main ──merge──> wmnn
     │               │                │
     │               │                │
  Feature Branch  Main Branch    WMNN Branch
  (pushable)      (PR only)    (merge from main only)
```

## Emergency Hook Bypass

**⚠️ Warning**: Use only in emergencies with team lead approval.

```bash
git push --no-verify origin <branch>
```

After bypassing hooks, you must document the reason in the commit message.

## FAQ

**Q: Why do we need these rules?**
A: To protect critical branch stability, ensure code quality, and prevent accidental direct commits.

**Q: What happens if I forget to install hooks?**
A: Local protection won't work, but GitHub branch protection rules will still block non-compliant pushes.

**Q: Can I delete the hooks?**
A: Technically yes, but strongly discouraged. It breaks the team's code management process.

**Q: What is the purpose of the wmnn branch?**
A: wmnn is a special integration branch for specific deployment or testing environments, accepting only validated code from main.

## Related Documentation

- [CONTRIBUTING.md](../../CONTRIBUTING.md) - Contribution Guide
- [CLAUDE.md](../../CLAUDE.md) - Claude Code Development Guide
