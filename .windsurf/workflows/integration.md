---
description: Mixxx Integration Branch Workflow
---

# Mixxx Integration Branch Workflow

This workflow describes the process for integrating multiple feature/bugfix branches into the integration branch for a combined bleeding-edge build.

## Prerequisites

- Main repo: `~/src/mixxx/` with `main` and `integration` branches
- Dev repo: `~/src/mixxx-dev/` with worktrees for individual branches
- Upstream remote: `mixxxdj/mixxx`
- Origin remote: `mxmilkiib/mixxx`

## Steps

### 1. Update Branches

Run the batch update script to rebase all worktree branches on upstream/main:

```bash
./update-branches.sh
```

### 2. Merge to Integration

Checkout the integration branch and merge upstream/main:

```bash
git checkout integration
git fetch upstream
git merge upstream/main
```

### 3. Merge Feature Branches

Merge each `[x]` marked branch from INTEGRATION.md that has "Next: Merge to integration":

```bash
git merge origin/<branch-name>
```

### 4. Resolve Conflicts

Common conflict types:
- Schema revisions: increment version numbers
- Enum IDs in trackmodel.h: assign unique IDs  
- Header declarations vs implementations: keep both sides

### 5. Update Documentation

Update INTEGRATION.md:
- Change `[ ]` to `[x]` for merged branches
- Update "Rebased" and "Updated" dates
- Update summary counts
- Update "Last updated" date

### 6. Build and Verify

```bash
cmake -B build -S . -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build --parallel
```

### 7. Sync to Gist

```bash
gh gist edit 5fb35c401736efed47ad7d78268c80b6 INTEGRATION.md
```

### 8. Push Changes

```bash
git push origin integration:integrated
```

## Important Rules

- Feature/fix branch history MUST NOT be rewritten unless complete and permission granted
- Integration branch can have merge commits
- Changes to upstream PRs MUST be incremental and easy to review
- UTF-8 string controls are LOCAL ONLY, never for upstream
- PRs go to mxmilkiib/mixxx first, then to mixxxdj/mixxx

## Checking PR Status

Use GitHub CLI to check PR status:
```bash
gh pr view <PR-number>
gh pr list --repo mixxxdj/mixxx --author mxmilkiib
```
