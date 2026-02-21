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

Commit INTEGRATION.md changes, then push gist:

```bash
 git add INTEGRATION.md && git commit -m "integration: ..."
 gh gist edit 5fb35c401736efed47ad7d78268c80b6 --filename INTEGRATION.md /home/milkii/src/mixxx/INTEGRATION.md
```

### 6. Build and Verify

**IMPORTANT**: After any new fix or branch is added to integration (including cherry-picks of bugfixes), the integration branch MUST be rebuilt before testing.

Incremental rebuild (most common — after cherry-picks or source changes):

```bash
 cmake --build /home/milkii/src/mixxx/build --target mixxx -- -j$(nproc --ignore=2)
```

Full reconfigure (only needed for new branches that add CMakeLists changes or new source files):

```bash
 cmake -B /home/milkii/src/mixxx/build -S /home/milkii/src/mixxx -DCMAKE_BUILD_TYPE=RelWithDebInfo
 cmake --build /home/milkii/src/mixxx/build --target mixxx -- -j$(nproc --ignore=2)
```

### 7. Sync to Gist

```bash
 gh gist edit 5fb35c401736efed47ad7d78268c80b6 --filename INTEGRATION.md /home/milkii/src/mixxx/INTEGRATION.md
```

## Important Rules

- Feature/fix branch history MUST NOT be rewritten unless complete and permission granted
- Integration branch can have merge commits
- **ALWAYS use `git merge` to bring branches into integration, never `git cherry-pick`** — cherry-picking creates duplicate commits with different SHAs, severs the branch relationship, makes bisect/revert unreliable, and hides what is actually in the build from `git log`
- Changes to upstream PRs MUST be incremental and easy to review
- UTF-8 string controls are LOCAL ONLY, never for upstream
- PRs go to mxmilkiib/mixxx first, then to mixxxdj/mixxx
- Permission MUST be sought before pushing to GitHub

## Worktree Branch Hygiene

**CRITICAL**: `mixxx-dev/` worktrees MUST only contain commits belonging to their named feature.

- NEVER commit INTEGRATION.md, integration merge commits, or unrelated fixups into a feature worktree
- INTEGRATION.md is tracked on the `integration` branch only; the gist is the prime source and must be kept in sync
- INTEGRATION.md MUST NOT be committed to any feature branch in `mixxx-dev/`
- Before making any edit in `mixxx-dev/`, confirm the active worktree matches the intended branch:
  ```bash
   git -C /home/milkii/src/mixxx-dev/<worktree>/ branch --show-current
  ```
- To verify a worktree is clean (only its own commits ahead of upstream/main):
  ```bash
   git -C /home/milkii/src/mixxx-dev/<worktree>/ log --oneline upstream/main..HEAD
  ```
- If a worktree has accumulated cruft, reset it:
  - No real feature commits yet: `git reset --hard upstream/main`
  - Has real commits mixed with cruft: rebase only the feature commits onto upstream/main, then force-update the branch ref

### Preventing Cross-Branch Contamination

- **ALWAYS create new feature branches from `upstream/main`, never from local `main`** — local `main` may have INTEGRATION.md commits or other local-only changes that will appear as extraneous commits in any upstream PR:
  ```bash
   git fetch upstream
   git worktree add /home/milkii/src/mixxx-dev/<name> -b feature/<branch-name> upstream/main
  ```
- **Before committing WIP in any worktree**, verify the branch is correct AND that the diff contains only changes belonging to that feature:
  ```bash
   git -C /home/milkii/src/mixxx-dev/<worktree>/ diff --stat
   git -C /home/milkii/src/mixxx-dev/<worktree>/ branch --show-current
  ```
- **If WIP from another feature is present in a worktree**, stash it before committing:
  ```bash
   git -C /home/milkii/src/mixxx-dev/<worktree>/ stash push --include-untracked -m "<description of what it is and where it belongs>"
  ```
- **Before opening or updating a PR**, verify the branch contains only its own commits relative to `upstream/main` (not local `main`):
  ```bash
   git log --oneline feature/<branch-name> --not upstream/main
  ```

## Checking PR Status

Use GitHub CLI to check PR status:

```bash
 gh pr view <PR-number>
 gh pr list --repo mixxxdj/mixxx --author mxmilkiib
```
