#!/bin/bash

# Batch update script for Mixxx development branches
# Updates all worktree branches in ~/src/mixxx-dev/ to latest upstream

set -e

echo "=== Starting batch branch update ==="
echo "Fetching upstream..."

# Fetch from main repo
git fetch upstream

echo "Updating worktree branches..."

# Update each worktree
for dir in ~/src/mixxx-dev/*/; do
    if [ -d "$dir" ]; then
        branch_name=$(basename "$dir")
        echo "=== Updating $branch_name ==="
        (
            cd "$dir"
            if git rebase upstream/main; then
                echo "✅ $branch_name rebased successfully"
                git push --force-with-lease origin HEAD
                echo "✅ $branch_name pushed to origin"
            else
                echo "❌ $branch_name failed to rebase"
                exit 1
            fi
        )
    fi
done

echo "=== Batch update complete ==="
