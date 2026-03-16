# GitHub Branch Protection Quick Setup Guide

## Quick Access

🔗 **Direct Link**: https://github.com/sipeed/picoclaw/settings/branches

## Step-by-Step Configuration

### 1. Configure `main` Branch Protection

**Add Rule** → Branch name pattern: `main`

**Copy-Paste Configuration**:
```
✅ Require a pull request before merging
   ✅ Require approvals: 1
   ✅ Dismiss stale pull request approvals when new commits are pushed

✅ Require status checks to pass before merging
   ✅ Require branches to be up to date before merging

✅ Require conversation resolution before merging

✅ Include administrators

✅ Restrict who can push to matching branches
   → Leave empty (no one can push directly)

❌ Allow force pushes (keep disabled)
❌ Allow deletions (keep disabled)
```

### 2. Configure `wmnn` Branch Protection

**Add Rule** → Branch name pattern: `wmnn`

**Copy-Paste Configuration**:
```
❌ Require a pull request before merging (keep disabled)

✅ Require status checks to pass before merging
   ✅ Require branches to be up to date before merging

✅ Include administrators

✅ Restrict who can push to matching branches
   → Add: @leoobai (or maintenance team)

❌ Allow force pushes (keep disabled)
❌ Allow deletions (keep disabled)
```

## Visual Checklist

### main Branch
- [ ] No direct pushes allowed
- [ ] Requires PR with 1 approval
- [ ] Status checks must pass
- [ ] Administrators included
- [ ] Force push disabled
- [ ] Deletion disabled

### wmnn Branch
- [ ] Only authorized users can push
- [ ] Direct merges from main allowed
- [ ] Status checks must pass
- [ ] Administrators included
- [ ] Force push disabled
- [ ] Deletion disabled

## Test After Setup

```bash
# Should FAIL
git push origin main

# Should SUCCEED (if authorized)
git checkout wmnn
git merge main
git push origin wmnn
```

## Need Help?

See detailed guide: [github_branch_protection_setup.md](github_branch_protection_setup.md)
