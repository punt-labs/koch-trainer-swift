#!/bin/bash
# Pre-tool hook: Block edits on main branch
# Reminds Claude to follow the worktree workflow in CLAUDE.md
# Exit code 0 = allow, exit code 2 = block

cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || cd "$(dirname "$0")/../.."

BRANCH=$(git branch --show-current 2>/dev/null)

if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
    cat <<'EOF'
BLOCKED: You are on the main branch.

**Read CLAUDE.md section "Development Workflow" before proceeding.**

The correct process is:
1. Create a worktree: make worktree-create BRANCH=feature/<name> NEW=1
2. cd to the worktree: cd ~/Coding/koch-trainer-worktrees/feature-<name>
3. Make your changes in the worktree

The workflow includes:
- Working a beads issue (bd ready, bd show, bd update)
- Creating commits with proper messages
- Creating PRs with gh pr create
- Session close protocol (git status, bd sync, git push)

Direct edits to main are not allowed. Use worktrees for all feature work.
EOF
    exit 2  # Exit code 2 = block
fi

exit 0
