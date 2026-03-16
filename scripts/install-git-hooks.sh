#!/bin/bash
# Install Git hooks for branch protection
# Run this script after cloning the repository

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

echo "Installing Git hooks for branch protection..."

# Create pre-push hook
cat > "$HOOKS_DIR/pre-push" << 'EOF'
#!/bin/bash
# Git pre-push hook to enforce branch protection rules
#
# Rules:
# 1. Prohibit direct push to main branch
# 2. Prohibit direct push to wmnn branch (except from main)
# 3. Only allow merges from main to wmnn

set -e

current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")

# Read push information from stdin
while read local_ref local_sha remote_ref remote_sha; do
    remote_branch=$(echo "$remote_ref" | sed 's|refs/heads/||')

    # Rule 1: Prohibit direct push to main branch
    if [ "$remote_branch" = "main" ]; then
        echo "❌ ERROR: Direct push to 'main' branch is prohibited!"
        echo ""
        echo "Please use Pull Requests to merge changes into main."
        echo ""
        echo "Workflow:"
        echo "  1. Create a feature branch: git checkout -b feature/your-feature"
        echo "  2. Push your branch: git push origin feature/your-feature"
        echo "  3. Create a Pull Request on GitHub"
        exit 1
    fi

    # Rule 2 & 3: Prohibit direct push to wmnn branch (except merges from main)
    if [ "$remote_branch" = "wmnn" ]; then
        # Check if this is a merge commit from main
        if [ "$local_sha" != "0000000000000000000000000000000000000000" ]; then
            # Get the parent commits
            parents=$(git rev-list --parents -n 1 "$local_sha" 2>/dev/null | wc -w)

            # If it's a merge commit (has 2+ parents)
            if [ "$parents" -gt 2 ]; then
                # Check if one parent is from main branch
                merge_base=$(git merge-base main "$local_sha" 2>/dev/null || echo "")
                main_head=$(git rev-parse main 2>/dev/null || echo "")

                if [ "$merge_base" != "$main_head" ]; then
                    echo "❌ ERROR: Can only merge from 'main' branch to 'wmnn' branch!"
                    echo ""
                    echo "Current operation is not a merge from main."
                    echo ""
                    echo "Correct workflow:"
                    echo "  1. git checkout wmnn"
                    echo "  2. git merge main"
                    echo "  3. git push origin wmnn"
                    exit 1
                fi
            else
                # Not a merge commit - prohibit direct push
                echo "❌ ERROR: Direct push to 'wmnn' branch is prohibited!"
                echo ""
                echo "Only merges from 'main' branch are allowed."
                echo ""
                echo "Correct workflow:"
                echo "  1. git checkout wmnn"
                echo "  2. git merge main"
                echo "  3. git push origin wmnn"
                exit 1
            fi
        fi
    fi
done

exit 0
EOF

chmod +x "$HOOKS_DIR/pre-push"

echo "✅ Git hooks installed successfully!"
echo ""
echo "Branch protection rules:"
echo "  1. ❌ Direct push to 'main' branch is prohibited"
echo "  2. ❌ Direct push to 'wmnn' branch is prohibited"
echo "  3. ✅ Only merges from 'main' to 'wmnn' are allowed"
echo ""
echo "To bypass hooks (not recommended): git push --no-verify"
