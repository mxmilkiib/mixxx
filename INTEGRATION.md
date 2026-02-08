prompt: local AI dev process; 2 repos, one individual branches, other for merging n test build

INTEGRATION.md

# Mixxx Integration Branch Configuration

> Last updated: 2026-02-06
> URL: https://gist.github.com/mxmilkiib/5fb35c401736efed47ad7d78268c80b6
> [RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119)

## Overview
This document tracks Milkii's personal Mixxx development setup for the creation and testing of feature and bugfix branches. It is a living document and SHOULD be updated as the workflow evolves.

- The goal is to maintain two Mixxx source instances: a main `mixxx` repo and a `mixxx-dev` repo.
- Both repos MUST maintain a `main` branch that is synced with `mixxxdj/mixxx` main.
- The `mixxx-dev` repo MUST use worktrees to host individual feature/fix branches, keeping them clean for upstream PRs.
- The `mixxx` repo MUST have an `integration` branch that combines multiple branches from the `mixxx-dev` repo.
- This dual setup SHOULD provide consistency for a stable bleeding-edge build without interference from local development.
- The integration outline, i.e. the indented list below, MUST reflect the state of the various branches, related issues and PRs, and dates.
- The integration merge process MUST follow the steps in the **Integration Merge Process** section below.
- PR urls SHOULD be checked regularly for status, new feedback, and todo items
- Related issues SHOULD be listed in the integration outline below
- Updates to PR status MUST be reflected in the integration outline below
- Each feature/fix branch SHOULD work standalone without depending on other local branches (except where noted)
- New branches MUST be created with a worktree in `mixxx-dev/` from the latest `mixxxdj/mixxx` main branch.
- Dates for branch creation, last PR comment, and last update MUST be recorded.
- Most branches MAY have related upstream issues.
- If any activity changes the state of a branch, the relevant part of the integration outline MUST be updated.
- INTEGRATION.md dates and statuses MUST be updated after changes and committed.
- A branch MUST be rebased as an initial step before any new changes are made to the branch
- All branches SHOULD be kept up-to-date and rebased with `mixxxdj/mixxx` main to minimize merge conflicts, except for local-only and merged branches
- Feature/fix branch history MUST NOT be rewritten unless the feature/fix is complete, then ask Milkii for permission to squash/rebase; integration branch can have merge commits.
- Changes to `mixxxdj/mixxx` PRs MUST be incremental so as to be easy to review, and MUST NOT completely reformulate a system in a single commit.
- Some features (UTF-8 string controls) MUST NOT be submitted to `mixxxdj/mixxx` upstream as they are local-only/personal use
- Merge conflict resolution and build verification are documented in the **Integration Merge Process** section below.
- Permission MUST be sought from the user before pushing commits to GitHub.
- PRs SHOULD be submitted to `mxmilkiib/mixxx`, and Milkii will create a further PR from there to `mixxxdj/mixxx`.
- Once the PR is accepted into `mixxxdj/mixxx`, the branch MUST be removed from integration tracking.
- If this file is updated, then it MUST be sent back to Gist by using `gh`.

## Directory Structure
| Path               | Purpose                                                 |
|--------------------|---------------------------------------------------------|
| `~/src/mixxx/`     | Main repo - `main` and `integration` branches           |
| `~/src/mixxx-dev/` | Development worktrees for feature/bugfix branches       |

---

## Branch and Integration Status Outline

**Summary**: 3 need attention, 11 awaiting review, 1 merged upstream, 7 local-only

- 🔴 **Needs Attention (CHANGES_REQUESTED)**
  - [x] **feature/2025.11nov.04-controller-wizard-quick-access** - [#15577](https://github.com/mixxxdj/mixxx/pull/15577)
    - Issue: [#12262](https://github.com/mixxxdj/mixxx/issues/12262)
    - Created: 2025-11-04, Last comment: none, Rebased: 2026-01-30, Updated: 2026-01-30
    - Next: Address ronso0 review feedback
    - Specific:
      - `devicesChanged` signal doesn't update menu after startup — try connecting to `ControllerManager::mappingApplied` instead (see #15524)
      - Action disable doesn't work on Qt 6.2.3 — menu item stays enabled/clickable
      - Unnecessary disconnect of `mappingEnded` — find more elegant way to prevent prefs dialog reopening when wizard launched from menu
      - Review comments on `dlgprefcontrollers.cpp` and `wmainmenubar.cpp`
  - [x] **feature/2025.10oct.21-stacked-overview-waveform** - [#15516](https://github.com/mixxxdj/mixxx/pull/15516)
    - Issue: [#13265](https://github.com/mixxxdj/mixxx/issues/13265)
    - Created: 2025-10-21, Last comment: 2025-10-21, Rebased: 2026-01-30, Updated: 2026-01-30
    - Next: Remove redundant HSV and LMH renderers (ronso0 feedback)
    - Specific:
      - Remove redundant Stacked HSV and Stacked LMH renderers — existing HSV/LMH already stack bands, nearly identical code
      - Remove unnecessary `static_cast<int>` — `pWaveform->getLow()` returns char, already implicitly promoted
      - PR marked stale (Jan 31 2026) — needs activity to unstale
      - Keep only Stacked RGB which ronso0 said "almost LGTM"
  - [x] **feature/2025.10oct.20-restore-last-library-selection** - [#15460](https://github.com/mixxxdj/mixxx/pull/15460)
    - Issue: [#10125](https://github.com/mixxxdj/mixxx/issues/10125)
    - Created: 2025-10-08, Last comment: 2025-11-14, Rebased: 2026-01-30, Updated: 2026-01-30
    - Next: Separate bugfix commits with explanations (ronso0 feedback)
    - Specific:
      - Separate minor bugfixes into individual commits with explanations of what was wrong
      - Store selection only on shutdown (destructor), not on every click
      - Don't write to config on every scroll
      - Don't remove existing code comments without reason
      - Use `VERIFY_OR_DEBUG_ASSERT` instead of manual validity checks for `QAbstractItemModel::match()` results
      - Unnecessary `reset()` on `std::unique_ptr` — explain or remove
      - Move code block up below `for` loop
      - Also awaiting review from daschuer
- 🟡 **Open PRs (REVIEW_REQUIRED)**
  - [x] **feature/2025.11nov.05-hide-unenabled-controllers** - [#15580](https://github.com/mixxxdj/mixxx/pull/15580)
    - Issue: [#14275](https://github.com/mixxxdj/mixxx/issues/14275)
    - Created: 2025-11-05, Last comment: none, Rebased: 2026-01-30, Updated: 2026-01-30
    - Next: Address ronso0 review feedback
    - Specific:
      - Rename "unenabled" to "disabled" everywhere — config keys, function names, and UI text (ronso0)
      - Remove unnecessary null check on `Controller*` — `DlgPrefController` ctor already asserts validity (ronso0)
      - Apply consistent naming across all touched files
  - [x] **feature/2025.11nov.05-waveform-cache-size-format** - [#15578](https://github.com/mixxxdj/mixxx/pull/15578)
    - Issue: [#14874](https://github.com/mixxxdj/mixxx/issues/14874)
    - Created: 2025-11-06, Last comment: 2025-11-05, Rebased: 2026-01-30, Updated: 2026-01-30
    - Next: Squash commits per Swiftb0y request
    - Specific:
      - Squash three commits into a single commit (Swiftb0y: "Would you mind squashing the three commits into a single one?")
  - [x] **bugfix/2025.11nov.04-reloop-shift-jog-seek** - [#15575](https://github.com/mixxxdj/mixxx/pull/15575)
    - Issue: [#12334](https://github.com/mixxxdj/mixxx/issues/12334)
    - Created: 2025-11-04, Last comment: none, Rebased: 2026-01-30, Updated: 2026-01-30
    - Next: Address ronso0 review feedback
    - Specific:
      - Use `engine.getValue(group, "track_loaded")` instead of current track check method (ronso0)
  - [x] **feature/2025.10oct.21-replace-libmodplug-with-libopenmpt** - [#15519](https://github.com/mixxxdj/mixxx/pull/15519)
    - Issue: [#9862](https://github.com/mixxxdj/mixxx/issues/9862)
    - Created: 2025-10-25, Last comment: 2025-10-25, Rebased: 2026-01-30, Updated: 2026-01-30
    - Next: Address daschuer architecture feedback
    - Specific:
      - DSP in SoundSource is "foreign to Mixxx" — daschuer wants bit-perfect decode, move DSP to effect rack instead
      - Rename constants to `kXBassBufferSize` style naming (daschuer)
      - Remove VS Code minimap `// MARK:` comments
      - Review comments on `trackerdsp.cpp` and `trackerdsp.h`
      - Windows CI test failure (`screenWillSentRawDataIfConfigured` timeout) — may be flaky or platform-specific `QImage` behavior
  - [x] **feature/2025.10oct.20-hotcues-on-overview-waveform** - [#15514](https://github.com/mixxxdj/mixxx/pull/15514)
    - Issue: [#14994](https://github.com/mixxxdj/mixxx/issues/14994)
    - Created: 2025-10-20, Last comment: 2026-01-19, Rebased: 2026-01-30, Updated: 2026-01-30
    - Next: Check recent comment, await review
    - Specific:
      - PR marked stale (Jan 19 2026) — needs activity to unstale
      - Paint hotcues on scaled image (option b) not full-width — scaling happens in OverviewCache so fixed pixel widths don't translate
      - Remove `// MARK:` comments
      - Get cue data from delegate columns instead of SQL queries (done)
      - Review feedback from ronso0 on marker rendering approach
  - [x] **feature/2025.10oct.17-library-column-hotcue-count** - [#15462](https://github.com/mixxxdj/mixxx/pull/15462)
    - Issue: [#15461](https://github.com/mixxxdj/mixxx/issues/15461)
    - Created: 2025-10-17, Last comment: 2026-01-17, Rebased: 2026-01-30, Updated: 2026-01-30
    - Next: Check recent comment, await review
    - Specific:
      - PR marked stale (Jan 17 2026) — needs activity to unstale
      - Broad discussion about whether hotcue count column is the right approach vs a "prepared" state flag (daschuer, ronso0)
      - Potential pie chart icon instead of plain number (daschuer suggestion)
      - Related to hotcues-on-overview-waveform PR #15514 (acolombier suggested rendering hotcues in overview column instead)
      - Schema change v39→v40 — will conflict with other schema changes
  - [ ] **feature/2025.11nov.17-deere-channel-mute-buttons** - [#15624](https://github.com/mixxxdj/mixxx/pull/15624)
    - Issue: [#15623](https://github.com/mixxxdj/mixxx/issues/15623)
    - Created: 2025-11-17, Last comment: 2025-11-20, Rebased: 2026-01-30, Updated: 2026-01-30
    - Next: Merge to integration, consider broader approach
    - Specific:
      - ronso0 questions necessity — "Why is the Vol fader not sufficient?"
      - daschuer suggests broader approach: knob widget with integrated kill/mute feature, explore Tremolo effect for "Transformer" effect, redirect energy to alternative EQ model / stem controls discussion
      - ronso0 agrees on knob with integrated kill, right-click behavior option in Preferences > Interface
      - Needs stronger justification or pivot to the broader knob-with-kill approach
  - [ ] **feature/2025.11nov.16-playback-position-control** - [#15617](https://github.com/mixxxdj/mixxx/pull/15617)
    - Issue: [#14288](https://github.com/mixxxdj/mixxx/issues/14288)
    - Created: 2025-11-16, Last comment: none, Rebased: 2026-01-30, Updated: 2026-01-30
    - Next: Merge to integration, await review
    - Specific:
      - No review comments yet
      - Adds `[Waveform],PlayMarkerPosition` ControlPotmeter (0.0–1.0)
      - Clean PR, just needs reviewer attention
  - [ ] **feature/2025.11nov.16-catalogue-number-column** - [#15616](https://github.com/mixxxdj/mixxx/pull/15616)
    - Issue: [#12583](https://github.com/mixxxdj/mixxx/issues/12583)
    - Created: 2025-11-16, Last comment: none, Rebased: 2026-01-30, Updated: 2026-01-30
    - Next: Merge to integration, await review
    - Specific:
      - No review comments yet
      - Schema migration revision 40 — will conflict with hotcue-count branch (also schema change)
      - Uses MusicBrainz Picard tag mapping conventions
  - [ ] **bugfix/2025.11nov.16-reloop-beatmix-mk2-naming** - [#15615](https://github.com/mixxxdj/mixxx/pull/15615)
    - Created: 2025-11-16, Last comment: none, Rebased: 2026-01-30, Updated: 2026-01-30
    - Next: Merge to integration, await review
    - Specific:
      - No review comments yet
      - Simple file rename PR, related to #12422 (MK1 support discussion)
  - [ ] **feature/2025.05may.14-fivefourths** - [#14780](https://github.com/mixxxdj/mixxx/pull/14780)
    - Issue: [#14686](https://github.com/mixxxdj/mixxx/issues/14686)
    - Created: 2025-05-14, Last comment: 2025-05-16, Rebased: 2026-01-30, Updated: 2026-01-30
    - Next: Fix tests, update manual, merge to integration
    - Specific:
      - Fix failing tests (Swiftb0y: "Next step would be to actually get the tests to pass")
      - Update the Mixxx manual (acolombier request)
      - daschuer has no objections to the CO approach
      - Swiftb0y confirmed no performance implications from new COs
- 🔵 **Local Only (No PR)**
  - [x] **feature/2025.10oct.14-waveform-hotcue-label-options**
    - Created: 2025-10-14, Rebased: 2026-01-30, Updated: 2026-01-30
    - Next: Maintain for personal use
  - [x] **feature/2025.10oct.08-utf8-string-controls**
    - Dependency for: hotcue-labelling, hotcue-label-options
    - Created: 2025-10-08, Rebased: 2026-01-30, Updated: 2026-01-30
    - Next: Maintain for personal use (not for upstream)
  - [x] **feature/2025.09sep.25-hotcue-labelling**
    - Created: 2025-09-25, Rebased: 2026-01-30, Updated: 2026-01-30
    - Next: Maintain for personal use
  - [x] **feature/2025.06jun.08-deere-deck-bg-colour**
    - Created: 2025-06-08, Rebased: 2026-01-30, Updated: 2026-01-30
    - Next: Maintain for personal use
  - [ ] **feature/2025.11nov.05-deere-waveform-zoom-deck-colors**
    - Created: 2025-11-05, Rebased: 2026-01-30, Updated: 2026-01-30
    - Next: Merge to integration, decide if PR-worthy
    - Specific:
      - Evaluate if the Deere-specific waveform zoom deck color change is worth a PR or remains personal use
      - Test visual appearance across deck configurations
  - [ ] **draft/2025.10oct.21-tracker-module-stems**
    - Created: 2025-10-21, Rebased: none, Updated: 2025-10-21
    - Next: Continue development or archive
    - Specific:
      - Depends on replace-libmodplug-with-libopenmpt (#15519) being accepted first
      - Adds stem support for tracker modules using libopenmpt
      - Not rebased — needs rebase before any work
  - [ ] **bugfix/qt6-guiprivate-missing-component**
    - Qt6 build fix
    - Created: unknown, Rebased: 2026-01-30, Updated: 2026-01-30
    - Next: Test if still needed, submit PR or delete
    - Specific:
      - Build with Qt6 to verify if `Qt6::GuiPrivate` component is still missing
      - If fixed upstream, delete branch and worktree
      - If still needed, create a proper PR
- ✅ **Merged to Upstream**
  - [x] ~~**bugfix/2025.11nov.04-fx-routing-persistence**~~ - [#15574](https://github.com/mixxxdj/mixxx/pull/15574)
    - Issue: [#14917](https://github.com/mixxxdj/mixxx/issues/14917)
    - Created: 2025-11-04, Last comment: 2025-11-14, Rebased: 2026-01-30, Updated: 2026-01-30
    - Next: Delete local branch
    - Specific:
      - Run `git worktree remove` if worktree exists
      - Delete local branch
      - Optionally delete remote branch from `mxmilkiib/mixxx`

### Branch Dependencies
```
utf8-string-controls (LOCAL_ONLY)
├── hotcue-labelling (LOCAL_ONLY)
└── hotcue-label-options (LOCAL_ONLY)
```

Branches with dependencies on local-only branches cannot be submitted upstream as-is. They MUST be refactored to remove the dependency or the dependency MUST be upstreamed first.

---

## TODO Summary
**Needs Attention (3 branches):**
- **controller-wizard-quick-access**: Check PR for specific review feedback
- **stacked-overview-waveform**: Remove redundant HSV and LMH renderers (ronso0 feedback)
- **restore-last-library-selection**: Separate bugfix commits with explanations (ronso0 feedback)

**Awaiting Review (8 branches):**
- hide-unenabled-controllers, waveform-cache-size-format, reloop-shift-jog-seek, replace-libmodplug-with-libopenmpt, fivefourths
- **Recent comments**: hotcues-on-overview-waveform (2026-01-19), library-column-hotcue-count (2026-01-17)

**Ready to Merge to Integration (5 branches):**
- deere-channel-mute-buttons, playback-position-control, catalogue-number-column, reloop-beatmix-mk2-naming, fivefourths

**Local Development (3 branches):**
- **Decide PR-worthiness**: deere-waveform-zoom-deck-colors
- **Continue or archive**: tracker-module-stems
- **Test if needed**: qt6-guiprivate-missing-component

**Cleanup:**
- Delete merged branch: fx-routing-persistence

---

## Testing Checklist (Before Pushing to PR upstream)
Pre:
- [ ] Branch rebased on latest `mixxxdj/mixxx` main

During:
- [ ] Builds without errors
- [ ] No new compiler warnings
- [ ] Basic functionality tested

Post:
- [ ] No regressions in related features

## Batch Branch Update Process
This process updates all feature/bugfix branches in `mixxx-dev/` to latest upstream:

- Upstream MUST be fetched first (from any worktree): `git fetch upstream`
- For each worktree directory in `~/src/mixxx-dev/`:
  - The branch MUST be rebased on upstream/main: `git rebase upstream/main`
  - Conflicts MUST be resolved if any occur
  - The rebased branch SHOULD be force-pushed to origin: `git push --force-with-lease origin HEAD`
  - The "Rebased" date in INTEGRATION.md MUST be updated
- Branches with unresolved conflicts SHOULD be noted for later attention
- After all branches are updated, the **Integration Merge Process** SHOULD be run

Automated via `./update-branches.sh` (run from `~/src/mixxx/`).

## Integration Merge Process
This process merges all `[x]` marked branches into the integration branch for a combined bleeding-edge build.

### Steps
1. **Commit pending INTEGRATION.md changes** (if any) before starting:
   ```bash
   git add INTEGRATION.md && git commit -m "update INTEGRATION.md before integration"
   ```
2. **Fetch upstream**
   ```bash
   git fetch upstream
   ```
3. **Run batch branch update** to rebase all worktree branches on upstream/main:
   ```bash
   ./update-branches.sh
   ```
4. **Checkout the integration branch**
   ```bash
   git checkout integration
   ```
5. **Merge upstream/main** into integration (merge, not rebase, to preserve integration history):
   ```bash
   git merge upstream/main
   ```
6. **Merge each `[x]` branch** from the outline that has "Next: Merge to integration":
   ```bash
   git merge origin/<branch-name>
   ```
7. **Resolve merge conflicts** carefully. Common issues:
   - Schema revisions: increment version numbers
   - Enum IDs in `trackmodel.h`: assign unique IDs
   - Header declarations vs implementations: keep both sides' additions
8. **Update INTEGRATION.md**:
   - Change `[ ]` to `[x]` for newly merged branches
   - Update "Rebased" and "Updated" dates to today
   - Update the summary line counts
   - Update the "Last updated" date at the top
9. **Build and verify**:
   ```bash
   cmake --build build --parallel
   ```
   - Basic functionality SHOULD be tested after build
10. **Sync to Gist** (if INTEGRATION.md was updated):
    ```bash
    gh gist edit 5fb35c401736efed47ad7d78268c80b6 INTEGRATION.md
    ```

## Outline Format Reference
This section documents the structure of this file for AI assistants and future maintainers.

### Branch Entry Format
Branch naming convention: feature/YYYY.MMmon.DD-thing-descriptive-title

```markdown
- [x] **branch-name** - [#PR](url)
  - Issue: [#ISSUE](url)
  - Optional description
  - Created: YYYY-MM-DD, Last comment: YYYY-MM-DD, Rebased: YYYY-MM-DD, Updated: YYYY-MM-DD
  - Next: Action item
```

- `[x]` = merged to integration, `[ ]` = not merged
- Branch name in bold
- PR link if exists, omit for local-only
- Issue link to related Mixxx issue/feature request (if applicable)
- Created date required for all branches
- Last comment date shows most recent PR comment ("none" if no comments), only for PRs
- Rebased date shows when branch was last rebased on `mixxxdj/mixxx` main ("none" if never)
- Updated date tracks last modification to branch
- Next action describes what needs to be done for this branch
- Within each section: `[x]` (integrated) branches first, then `[ ]` (not integrated) branches
- Within each group (`[x]` or `[ ]`), sort by updated date (newest first)

### Section Order
1. Needs Attention (CHANGES_REQUESTED)
2. Open PRs (REVIEW_REQUIRED)
3. Local Only (No PR)
4. Merged to Upstream

### Summary Line
**When updating integration**: Update the "Last updated" date at the top of this file.

Update the summary line at the top when adding/removing branches:
```markdown
**Summary**: X PRs need attention, Y open PRs awaiting review, Z merged upstream, W local-only branches
```

MIXXX_INTEGRATION.md

# Mixxx Integration Branch Configuration

> Last updated: 2026-01-30
> URL: https://gist.github.com/mxmilkiib/5fb35c401736efed47ad7d78268c80b6

## Overview

This document tracks Milkii's personal Mixxx development setup for the creation and testing of feature and bugfix branches. It is a living document and should be updated as the workflow evolves.

- The goal is to maintain two Mixxx source instances: a main `mixxx` repo and a `mixxx-dev` repo.
- Both repos MUST maintain a `main` branch that is synced with `mixxxdj/mixxx` main.
- The `mixxx-dev` repo MUST use worktrees to host individual feature/fix branches, keeping them clean for upstream PRs.
- The `mixxx` repo MUST have an `integration` branch that combines multiple branches from the `mixxx-dev` repo.
- This dual setup SHOULD provide consistency for a stable bleeding-edge build without interference from local development.
- The integration outline list below MUST reflect the state of the various branches, related issues and PRs, and dates. 
- PR urls SHOULD be checked regularly for status, new feedback, and todo items
- Updates to PR status MUST be reflected in the feature/fix outline below
- Each feature/fix branch SHOULD work standalone without depending on other local branches (except where noted)
- New branches MUST be created with a worktree in `mixxx-dev/` from the latest `mixxxdj/mixxx` main branch.
- Dates for branch creation, last PR comment, and last update MUST be recorded.
- Most branches will have upstream issues, though some might not or are local-only.
- If any activity changes the state of a branch, the relevant part of the integration outline MUST be updated.
- Rebases MUST be done as an initial step before any changes are made to the branch, and at least fortnightly for housekeeping
- Feature/fix branch history MUST NOT be rewritten unless the feature/fix is complete, then ask permission to squash/rebase; integration branch can have merge commits.
- Changes to `mixxxdj/mixxx` PRs MUST be incremental so as to be easy to review, and MUST NOT completely reformulate a system in a single commit.
- Some features (UTF-8 string controls) MUST NOT be submitted to `mixxxdj/mixxx` upstream as they are local-only/personal use
- Branches SHOULD be kept up-to-date and rebased with `mixxxdj/mixxx` main to minimize merge conflicts
- When merging to integration, merge conflicts MUST be resolved carefully; common issues:
  - Schema revisions (increment version numbers)
  - Enum IDs in `trackmodel.h` (assign unique IDs)
  - Header declarations vs implementations (keep both sides' additions)
- The integration branch MUST be verified to build successfully before committing merged features
- Permission MUST be sought from the user before pushing commits to GitHub.
- PRs are submitted to `mxmilkiib/mixxx`, and Milkii will create a further PR from there to `mixxxdj/mixxx`.
- Once the PR is accepted into `mixxxdj/mixxx`, the branch MUST be removed from integration tracking.


### Branch Dependencies

```
utf8-string-controls (LOCAL_ONLY)
├── hotcue-labelling (LOCAL_ONLY)
└── hotcue-label-options (LOCAL_ONLY)
```

Branches with dependencies on local-only branches cannot be submitted upstream as-is. They must be refactored to remove the dependency or the dependency must be upstreamed first.

## Directory Structure

| Path | Purpose |
|------|---------|
| `~/src/mixxx/` | Main repo - `main` and `integration` branches |
| `~/src/mixxx-dev/` | Development worktrees for feature/bugfix branches |

## Legend

| Symbol | Meaning |
|--------|---------|
| `[x]` | Merged to integration branch |
| `[ ]` | Not yet merged to integration |

**Date format**: (branch created, last PR comment, last rebased, last updated)

**When updating integration**: Update the "Last updated" date at the top of this file.

---

## Integration Branch Status

**Summary**: 3 need attention, 11 awaiting review, 1 merged upstream, 7 local-only

- **Needs Attention (CHANGES_REQUESTED)**
  - [x] **feature/2025.11nov.04-controller-wizard-quick-access** - [#15577](https://github.com/mixxxdj/mixxx/pull/15577)
    - Issue: [#12262](https://github.com/mixxxdj/mixxx/issues/12262)
    - Created: 2025-11-04, Last comment: none, Rebased: 2026-01-28, Updated: 2026-01-28
    - Next: Check PR for specific review feedback
  - [x] **feature/2025.10oct.21-stacked-overview-waveform** - [#15516](https://github.com/mixxxdj/mixxx/pull/15516)
    - Issue: [#13265](https://github.com/mixxxdj/mixxx/issues/13265)
    - Created: 2025-10-21, Last comment: 2025-10-21, Rebased: 2026-01-28, Updated: 2026-01-28
    - Next: Remove redundant HSV and LMH renderers (ronso0 feedback)
  - [x] **feature/2025.10oct.20-restore-last-library-selection** - [#15460](https://github.com/mixxxdj/mixxx/pull/15460)
    - Issue: [#10125](https://github.com/mixxxdj/mixxx/issues/10125)
    - Created: 2025-10-08, Last comment: 2025-11-14, Rebased: 2026-01-28, Updated: 2026-01-28
    - Next: Separate bugfix commits with explanations (ronso0 feedback)
- **Open PRs (REVIEW_REQUIRED)**
  - [x] **feature/2025.11nov.05-hide-unenabled-controllers** - [#15580](https://github.com/mixxxdj/mixxx/pull/15580)
    - Issue: [#14275](https://github.com/mixxxdj/mixxx/issues/14275)
    - Created: 2025-11-05, Last comment: none, Rebased: 2026-01-28, Updated: 2026-01-28
    - Next: Await review
  - [x] **feature/2025.11nov.05-waveform-cache-size-format** - [#15578](https://github.com/mixxxdj/mixxx/pull/15578)
    - Issue: [#14874](https://github.com/mixxxdj/mixxx/issues/14874)
    - Created: 2025-11-06, Last comment: 2025-11-05, Rebased: 2026-01-28, Updated: 2026-01-28
    - Next: Await review
  - [x] **bugfix/2025.11nov.04-reloop-shift-jog-seek** - [#15575](https://github.com/mixxxdj/mixxx/pull/15575)
    - Issue: [#12334](https://github.com/mixxxdj/mixxx/issues/12334)
    - Created: 2025-11-04, Last comment: none, Rebased: 2026-01-28, Updated: 2026-01-28
    - Next: Await review
  - [x] **feature/2025.10oct.21-replace-libmodplug-with-libopenmpt** - [#15519](https://github.com/mixxxdj/mixxx/pull/15519)
    - Issue: [#9862](https://github.com/mixxxdj/mixxx/issues/9862)
    - Created: 2025-10-25, Last comment: 2025-10-25, Rebased: 2026-01-28, Updated: 2026-01-28
    - Next: Await review
  - [x] **feature/2025.10oct.20-hotcues-on-overview-waveform** - [#15514](https://github.com/mixxxdj/mixxx/pull/15514)
    - Issue: [#14994](https://github.com/mixxxdj/mixxx/issues/14994)
    - Created: 2025-10-20, Last comment: 2026-01-19, Rebased: 2026-01-28, Updated: 2026-01-28
    - Next: Check recent comment, await review
  - [x] **feature/2025.10oct.17-library-column-hotcue-count** - [#15462](https://github.com/mixxxdj/mixxx/pull/15462)
    - Issue: [#15461](https://github.com/mixxxdj/mixxx/issues/15461)
    - Created: 2025-10-17, Last comment: 2026-01-17, Rebased: 2026-01-28, Updated: 2026-01-28
    - Next: Check recent comment, await review
  - [ ] **feature/2025.11nov.17-deere-channel-mute-buttons** - [#15624](https://github.com/mixxxdj/mixxx/pull/15624)
    - Issue: [#15623](https://github.com/mixxxdj/mixxx/issues/15623)
    - Created: 2025-11-17, Last comment: 2025-11-20, Rebased: 2026-01-28, Updated: 2026-01-28
    - Next: Merge to integration, await review
  - [ ] **feature/2025.11nov.16-playback-position-control** - [#15617](https://github.com/mixxxdj/mixxx/pull/15617)
    - Issue: [#14288](https://github.com/mixxxdj/mixxx/issues/14288)
    - Created: 2025-11-16, Last comment: none, Rebased: 2026-01-28, Updated: 2026-01-28
    - Next: Merge to integration, await review
  - [ ] **feature/2025.11nov.16-catalogue-number-column** - [#15616](https://github.com/mixxxdj/mixxx/pull/15616)
    - Issue: [#12583](https://github.com/mixxxdj/mixxx/issues/12583)
    - Created: 2025-11-16, Last comment: none, Rebased: 2026-01-28, Updated: 2026-01-28
    - Next: Merge to integration, await review
  - [ ] **bugfix/2025.11nov.16-reloop-beatmix-mk2-naming** - [#15615](https://github.com/mixxxdj/mixxx/pull/15615)
    - Created: 2025-11-16, Last comment: none, Rebased: 2026-01-28, Updated: 2026-01-28
    - Next: Merge to integration, await review
  - [ ] **feature/2025.05may.14-fivefourths** - [#14780](https://github.com/mixxxdj/mixxx/pull/14780)
    - Issue: [#14686](https://github.com/mixxxdj/mixxx/issues/14686)
    - Created: 2025-05-14, Last comment: 2025-05-16, Rebased: 2026-01-28, Updated: 2026-01-28
    - Next: Merge to integration, await review
- **Local Only (No PR)**
  - [x] **feature/2025.10oct.14-waveform-hotcue-label-options**
    - Created: 2025-10-14, Rebased: 2026-01-28, Updated: 2026-01-28
    - Next: Maintain for personal use
  - [x] **feature/2025.10oct.08-utf8-string-controls**
    - Dependency for: hotcue-labelling, hotcue-label-options
    - Created: 2025-10-08, Rebased: 2026-01-28, Updated: 2026-01-28
    - Next: Maintain for personal use (not for upstream)
  - [x] **feature/2025.09sep.25-hotcue-labelling**
    - Created: 2025-09-25, Rebased: 2026-01-28, Updated: 2026-01-28
    - Next: Maintain for personal use
  - [x] **feature/2025.06jun.08-deere-deck-bg-colour**
    - Created: 2025-06-08, Rebased: 2026-01-28, Updated: 2026-01-28
    - Next: Maintain for personal use
  - [ ] **feature/2025.11nov.05-deere-waveform-zoom-deck-colors**
    - Created: 2025-11-05, Rebased: 2026-01-28, Updated: 2026-01-28
    - Next: Merge to integration, decide if PR-worthy
  - [ ] **draft/2025.10oct.21-tracker-module-stems**
    - Created: 2025-10-21, Rebased: none, Updated: 2025-10-21
    - Next: Continue development or archive
  - [ ] **bugfix/qt6-guiprivate-missing-component**
    - Qt6 build fix
    - Created: unknown, Rebased: 2026-01-28, Updated: 2026-01-28
    - Next: Test if still needed, submit PR or delete
- **Merged to Upstream**
  - [x] ~~**bugfix/2025.11nov.04-fx-routing-persistence**~~ - [#15574](https://github.com/mixxxdj/mixxx/pull/15574)
    - Issue: [#14917](https://github.com/mixxxdj/mixxx/issues/14917)
    - Created: 2025-11-04, Last comment: 2025-11-14, Rebased: 2026-01-28, Updated: 2026-01-28
    - Next: Delete local branch

---

## Testing Checklist (Before Pushing to PR upstream)

- [ ] Branch rebased on latest `mixxxdj/mixxx` main
- [ ] Builds without errors
- [ ] No new compiler warnings
- [ ] Basic functionality tested
- [ ] No regressions in related features

---

## Document Format Reference

This section documents the structure of this file for AI assistants and future maintainers.

### Branch Entry Format

```markdown
- [x] **branch-name** - [#PR](url)
  - Issue: [#ISSUE](url)
  - Optional description
  - Created: YYYY-MM-DD, Last comment: YYYY-MM-DD, Rebased: YYYY-MM-DD, Updated: YYYY-MM-DD
  - Next: Action item
```

- `[x]` = merged to integration, `[ ]` = not merged
- Branch name in bold
- PR link if exists, omit for local-only
- Issue link to related Mixxx issue/feature request (if applicable)
- Created date required for all branches
- Last comment date shows most recent PR comment ("none" if no comments), only for PRs
- Rebased date shows when branch was last rebased on `mixxxdj/mixxx` main ("none" if never)
- Updated date tracks last modification to branch
- Next action describes what needs to be done for this branch
- Within each section: `[x]` (integrated) branches first, then `[ ]` (not integrated) branches
- Within each group (`[x]` or `[ ]`), sort by updated date (newest first)

### Section Order

1. Needs Attention (CHANGES_REQUESTED)
2. Open PRs (REVIEW_REQUIRED)
3. Local Only (No PR)
4. Merged to Upstream

### Summary Line

Update the summary line at the top when adding/removing branches:
```markdown
**Summary**: X PRs need attention, Y open PRs awaiting review, Z merged upstream, W local-only branches
```
