#!/bin/bash
# Remove .env.automation from entire git history using git filter-branch
# This script is bash-compatible for use with git on Windows

set -e

echo "Removing .env.automation from entire git history..."

# Create a backup branch
BACKUP_BRANCH="backup/before-secret-removal-$(date +%Y%m%d-%H%M%S)"
echo "Creating backup branch: $BACKUP_BRANCH"
git branch "$BACKUP_BRANCH"
echo "✓ Backup created"

# Set environment variable to suppress warning
export FILTER_BRANCH_SQUELCH_WARNING=1

echo "Running git filter-branch..."

# Remove .env.automation from all commits using bash syntax
git filter-branch --force \
    --tree-filter 'rm -f .env.automation' \
    -- --all

echo "✓ Secret file removed from history"

# Verify the file is gone
if git log --all --oneline -- .env.automation 2>/dev/null | grep -q .; then
    echo "❌ Warning: .env.automation still found in history"
    exit 1
fi

echo "✓ Verified: .env.automation completely removed"
echo ""
echo "Next steps:"
echo "1. Review changes: git log --oneline -10"
echo "2. If satisfied, force-push: git push origin --all --force-with-lease"
echo "3. If issues, restore: git reset --hard $BACKUP_BRANCH"
