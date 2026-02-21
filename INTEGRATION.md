prompt: local AI dev process; 2 repos, one individual branches, other for merging n test build

INTEGRATION.md

# Mixxx Integration Branch Configuration

> Last updated: 2026-02-21 02:10
> URL: https://gist.github.com/mxmilkiib/5fb35c401736efed47ad7d78268c80b6
> [RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119)

## Overview / rules

- This document tracks Milkii's personal Mixxx development setup, for creating and testing feature and bugfix branches.
- This is a living document and SHOULD be updated as the workflow evolves.
- The goal is to maintain two Mixxx source instances: a main `mixxx` repo and a `mixxx-dev` repo.
- Both repos MUST maintain a `main` branch that is synced with `mixxxdj/mixxx` main.
- The `mixxx-dev` repo MUST use worktrees to host individual feature/fix branches, keeping them clean for upstream PRs.
- The `mixxx` repo MUST have an `integration` branch that combines multiple branches from the `mixxx-dev` repo.
- All individual branch development should be done using the `mixxx-dev` directory repository
- `mixxx` can have some edits for testing purposes, but should be kept minimal
- A branch in `mixxx-dev` MUST have clean commits before first being linked with a GitHub PR
- All branches SHOULD be kept up-to-date and rebased with `mixxxdj/mixxx` main to minimize merge conflicts, except merged branches
- A branch MUST be rebased as an initial step before any new change is made to said branch
- This dual setup SHOULD provide consistency for a stable bleeding-edge build without interference from local development.
- The integration merge process MUST follow the steps in the **Integration Merge Process** section below.
- Changes to `mixxxdj/mixxx` PRs MUST be incremental so as to be easy to review, and MUST NOT completely reformulate a system in a single commit.
- The integration status outline MUST reflect the state of all branches, related issues, PRs, and dates, and MUST be updated after changes are committed — PR URLs SHOULD be checked first to catch new feedback
- Most branches MAY have related upstream issues; related issues SHOULD be listed in the outline
- Feature and fix branches should be in the correct outline sections
- Dates for branch creation, last PR comment, and last update MUST be recorded in the status outline
- Each feature/fix branch SHOULD work standalone without depending on other local branches (except where noted)
- Feature/fix branch history MUST NOT be rewritten unless the feature/fix is complete
- Ask Milkii for permission to squash/rebase; integration branch can have merge commits.
- Any fix or feature branch that relies on another local branch MUST be noted in the Branch Dependencies section
- Some features (UTF-8 string controls) MUST NOT be submitted to `mixxxdj/mixxx` upstream as they are local-only/personal use
- PRs SHOULD be submitted to `mxmilkiib/mixxx`, and Milkii will create a further PR from there to `mixxxdj/mixxx`.
- Once the PR is fully merged into `mixxxdj/mixxx`, the branch MUST be removed from integration tracking.
- The "Last updated" date at the top of this file MUST be updated whenever this file is edited
- If this file is updated, it MUST be synced to Gist: run `gh gist edit 5fb35c401736efed47ad7d78268c80b6 --filename INTEGRATION.md INTEGRATION.md` from `~/src/mixxx/` (`--filename` targets the gist file, the positional arg supplies the local content)
- Commit messages must not be to verbose, and should be concise and descriptive.
- Git operations MUST be non-interactive using `GIT_EDITOR=true` and `GIT_PAGER=cat` to avoid vim/editor prompts
- When resolving merge conflicts during rebases, conflicts MUST be resolved and the rebase continued non-interactively
- Code quality MUST be verified before pushing - code should be proper, straight to the point, robust, and follow Mixxx coding style
- Permission MUST be sought from the user before pushing commits to GitHub.

## Directory Structure

| Path               | Purpose                                                 |
|--------------------|---------------------------------------------------------|
| `~/src/mixxx/`     | Main repo - `main` and `integration` branches           |
| `~/src/mixxx-dev/` | Development worktrees for feature/fix branches          |

### Branch Dependencies

```
utf8-string-controls (LOCAL_ONLY)
├── hotcue-labelling (LOCAL_ONLY)
└── hotcue-label-options (LOCAL_ONLY)
```

Branches with dependencies on local-only branches cannot be submitted upstream as-is. They MUST be refactored to remove the dependency or the dependency MUST be upstreamed first.

## Branch and Integration Status Outline

**Summary**: 0 need attention, 18 awaiting review, 5 merged upstream, 8 local-only

> Integration rebuilt 2026-02-19: applied waveform FBO + openglwindow resize fixes; fixed hotcue-labelling merge (missing setLabel/slotHotcueLabelChangeRequest); merged midi-makeinputhandler-null-engine bugfix (was missing, caused SIGSEGV/SIGABRT on controller shutdown)
> Integration rebuilt 2026-02-19 (second time): removed hotcue-count and catalogue-number branches — both require schema changes (v41, v42) that caused a cross-thread SQLite crash (SIGSEGV in BaseTrackCache::updateIndexWithQuery via Qt::DirectConnection on engine thread). Schema kept at upstream v40.
> Integration patched 2026-02-19: midi-makeinputhandler-null-engine fix was missing from the rebuild — caused repeated SIGSEGV/SIGABRT on controller shutdown (MidiControllerJSProxy::makeInputHandler null shared_ptr). Re-merged.
> Wayland root cause identified 2026-02-19: QOpenGLWindow subsurface resize blocks on compositor buffer realloc; workaround QT_QPA_PLATFORM=xcb
> XCB resize gap 2026-02-19: WA_PaintOnScreen approach abandoned — WGLWidget lacks paintEngine(), causes heap corruption abort; gap is inherent to QOpenGLWindow+createWindowContainer
> Integration updated 2026-02-20: added controlpickermenu-quickfx-deck-offset (#16019), fix-learning-wizard-from-prefs-button; fixed hotcue-labelling missing setLabel/slotHotcueLabelChangeRequest; build clean
> Integration updated 2026-02-21: merged simple-waveform-top-and-overview (Simple to top of main waveform list; Simple overview type)
> Integration updated 2026-02-21 (2): added Layered (LMH tail-to-tail) and Stems (stem channels) as main waveform types; build clean
> Integration updated 2026-02-21 (3): added CQT spectrogram main waveform type (frequency-band heatmap, showcqt-style hue mapping); build clean

- 🔴 **Needs Attention (CHANGES_REQUESTED)**
  - *(none)*
- 🟡 **BUG FIXES - Open PRs (REVIEW_REQUIRED)**
  - [x] **bugfix/2026.02feb.20-controlpickermenu-quickfx-deck-offset** - REVIEW_REQUIRED
    - Issue: [#16017](https://github.com/mixxxdj/mixxx/issues/16017)
    - Created: 2026-02-20, Last comment: none, Rebased: 2026-02-20, Updated: 2026-02-20
    - Next: Track upstream PR #16019 (ronso0), submit own PR or drop when merged
    - Specifics:
      - `groupForDeck(i)` should be `groupForDeck(i - 1)` — loop is 1-indexed, function is 0-indexed
      - Upstream PR #16019 by ronso0 targets 2.6; this branch applies same fix to main
    - Tested?: no
  - [x] **bugfix/2026.02feb.20-fix-learning-wizard-from-prefs-button** - REVIEW_REQUIRED
    - Created: 2026-02-20, Last comment: none, Rebased: 2026-02-20, Updated: 2026-02-20
    - Next: Submit PR, await review
    - Specifics:
      - DlgControllerLearning is parented to DlgPrefController (child of DlgPreferences)
      - Previously mappingStarted() emitted after show(), causing prefs dialog to cascade-hide the wizard
      - Fix: emit mappingStarted() before creating and showing the wizard
    - Tested?: yes
  - [x] **bugfix/2026.02feb.18-midi-makeinputhandler-null-engine** - [#16003](https://github.com/mixxxdj/mixxx/pull/16003) - REVIEW_REQUIRED
    - Created: 2026-02-18, Last comment: none, Rebased: 2026-02-20, Updated: 2026-02-18
    - Next: Await review
    - Tested?: yes
  - [x] **bugfix/2026.02feb.19-textured-waveform-fbo-resize** - [#16010](https://github.com/mixxxdj/mixxx/pull/16010) - REVIEW_REQUIRED
    - Created: 2026-02-19, Last comment: none, Updated: 2026-02-19
    - Next: Await review
    - Specifics:
      - Improved: defer FBO reallocation to paintGL via m_pendingResize flag
    - Tested?: yes
  - [x] **bugfix/2026.02feb.19-openglwindow-resize-repaint** - [#16012](https://github.com/mixxxdj/mixxx/pull/16012) - REVIEW_REQUIRED
    - Created: 2026-02-19, Last comment: none, Updated: 2026-02-19
    - Next: Await review
    - Specifics:
      - Restores m_dirty flag: defers extra paintGL+swapBuffers from resizeGL to next vsync
      - Does not fix Wayland resize lag (compositor-level issue)
    - Tested?: yes
  - [x] **bugfix/2026.02feb.19-wayland-opengl-resize-warning** - [#16014](https://github.com/mixxxdj/mixxx/pull/16014) - DRAFT - REVIEW_REQUIRED
    - Issue: [#16013](https://github.com/mixxxdj/mixxx/issues/16013)
    - Created: 2026-02-19, Last comment: none, Updated: 2026-02-19
    - Next: Await review
    - Specifics:
      - Wayland + QOpenGLWindow subsurface resize causes synchronous compositor buffer realloc on every pixel of drag
      - Workaround: QT_QPA_PLATFORM=xcb (XWayland)
      - Adds qWarning at startup when Wayland detected with OpenGL waveforms
    - Tested?: yes
- 🟡 **NEW FEATURES - Open PRs (REVIEW_REQUIRED)**
  - [x] **feature/2026.02feb.20-simple-waveform-top-and-overview** - [#16021](https://github.com/mixxxdj/mixxx/pull/16021) - REVIEW_REQUIRED
    - Issue: [#16020](https://github.com/mixxxdj/mixxx/issues/16020)
    - Created: 2026-02-20, Last comment: none, Rebased: 2026-02-20, Updated: 2026-02-21
    - Next: Await review
    - Specifics:
      - Moves Simple to top of main waveform type combobox (after alphabetical sort)
      - Adds Simple as an overview waveform type (amplitude envelope, signal color, stereo mirrored)
      - Moves Simple to top of overview waveform combobox
      - Adds Layered (LMH bands stacked tail-to-tail) as main waveform type
      - Adds Stems (stem channels stacked tail-to-tail, `__STEM__` only) as main waveform type
      - Adds CQT spectrogram main waveform type (frequency×time heatmap, showcqt-style hue: low=red, mid=green, high=blue)
    - Tested?: no
  - [x] **feature/2025.10oct.20-restore-last-library-selection** - [#15460](https://github.com/mixxxdj/mixxx/pull/15460) - DRAFT - REVIEW_REQUIRED
    - Issue: [#10125](https://github.com/mixxxdj/mixxx/issues/10125)
    - Created: 2025-10-08, Last comment: 2026-02-18, Rebased: 2026-02-20, Updated: 2026-02-19
    - Next: Await re-review — ronso0 CHANGES_REQUESTED (Nov 17) addressed in Feb 18 rebase
    - Specifics:
      - ~~Separate commits for changes~~ done - 4 commits with explanations
      - ~~Store selection with debounced saves~~ done - 3 second debounce timer
      - ~~Use VERIFY_OR_DEBUG_ASSERT~~ done
      - ~~Root node crash in saveSelectionToConfig~~ fixed
      - ~~scheduleSelectionSave never called from clicked()~~ fixed
      - ~~DataRole mismatch in restoreLastSelection~~ fixed — uses Qt::DisplayRole
      - ~~activateDefaultSelection overwriting restore~~ fixed — conditional fallback
      - ~~Feature not activated on restore~~ fixed — activate()/activateChild() called
      - Track row selection save/restore added via WTrackTableView
    - Tested?: yes
  - [x] **feature/2025.11nov.04-controller-wizard-quick-access** - [#15577](https://github.com/mixxxdj/mixxx/pull/15577) - REVIEW_REQUIRED
    - Issue: [#12262](https://github.com/mixxxdj/mixxx/issues/12262)
    - Created: 2025-11-04, Last comment: 2026-02-18, Rebased: 2026-02-20, Updated: 2026-02-18
    - Next: Await review
    - Specifics:
      - ~~devicesChanged not updating menu post-startup~~ fixed — connected to mappingApplied
      - ~~range-for style on m_controllerPages~~ done
    - Tested?: yes
  - [x] **feature/2025.10oct.21-stacked-overview-waveform** - [#15516](https://github.com/mixxxdj/mixxx/pull/15516) - DRAFT - REVIEW_REQUIRED
    - Issue: [#13265](https://github.com/mixxxdj/mixxx/issues/13265)
    - Created: 2025-10-21, Last comment: 2026-02-17, Rebased: 2026-02-20, Updated: 2026-02-18
    - Next: Await review
    - Specifics:
      - ~~Remove redundant Stacked HSV and Stacked LMH renderers~~ done
      - ~~Remove unnecessary static_cast<int>~~ done
      - ~~Rename "Stacked (RGB)" to "Stacked"~~ done
      - All feedback addressed
      - Left comment 2026-02-17 re: Filtered/Stacked naming confusion — see #15996
    - Tested?: yes
  - [x] **feature/2025.11nov.05-hide-unenabled-controllers** - [#15580](https://github.com/mixxxdj/mixxx/pull/15580) - REVIEW_REQUIRED
    - Issue: [#14275](https://github.com/mixxxdj/mixxx/issues/14275)
    - Created: 2025-11-05, Last comment: none, Rebased: 2026-02-20, Updated: 2026-02-08
    - Next: Await review
    - Specifics:
      - ~~Rename "unenabled" to "disabled" everywhere — config keys, function names, and UI text (ronso0)~~ done
      - ~~Remove unnecessary null check on `Controller*` — `DlgPrefController` ctor already asserts validity (ronso0)~~ done
      - ~~Apply consistent naming across all touched files~~ done
      - All feedback addressed, awaiting final review
    - Tested?: yes
  - [x] **feature/2025.10oct.21-replace-libmodplug-with-libopenmpt** - [#15519](https://github.com/mixxxdj/mixxx/pull/15519) - DRAFT - REVIEW_REQUIRED
    - Issue: [#9862](https://github.com/mixxxdj/mixxx/issues/9862)
    - Created: 2025-10-25, Last comment: 2025-11-22, Rebased: 2026-02-20, Updated: 2026-01-30
    - Next: Address daschuer architecture feedback
    - Specifics:
      - DSP in SoundSource is "foreign to Mixxx" — daschuer wants bit-perfect decode, move DSP to effect rack instead
      - Rename constants to `kXBassBufferSize` style naming (daschuer)
      - Remove VS Code minimap `// MARK:` comments
      - Review comments on `trackerdsp.cpp` and `trackerdsp.h`
      - Windows CI test failure (`screenWillSentRawDataIfConfigured` timeout) — may be flaky or platform-specific `QImage` behavior
      - Test fix 2026-02-19: `taglibStringToEnumFileType` now excludes all openmpt tracker formats (mod, s3m, xm, it, mptm, 669, amf, ams, dbm, dmf, dsm, far, mdl, med, mtm, mt2, psm, ptm, ult, umx) — none are taglib formats
    - Tested?: no
  - [x] **feature/2025.10oct.20-hotcues-on-overview-waveform** - [#15514](https://github.com/mixxxdj/mixxx/pull/15514) - DRAFT - REVIEW_REQUIRED
    - Issue: [#14994](https://github.com/mixxxdj/mixxx/issues/14994)
    - Created: 2025-10-20, Last comment: 2026-01-19, Rebased: 2026-02-20, Updated: 2026-01-30
    - Next: Check recent comment, await review
    - Specifics:
      - PR marked stale (Jan 19 2026) — needs activity to unstale
      - Paint hotcues on scaled image (option b) not full-width — scaling happens in OverviewCache so fixed pixel widths don't translate
      - Remove `// MARK:` comments
      - Get cue data from delegate columns instead of SQL queries (done)
      - Review feedback from ronso0 on marker rendering approach
    - Tested?: no
  - [ ] **feature/2025.10oct.17-library-column-hotcue-count** - [#15462](https://github.com/mixxxdj/mixxx/pull/15462) - REVIEW_REQUIRED
    - Issue: [#15461](https://github.com/mixxxdj/mixxx/issues/15461)
    - Created: 2025-10-17, Last comment: 2026-01-17, Rebased: 2026-02-20, Updated: 2026-01-30
    - Next: Check recent comment, await review
    - Specifics:
      - PR marked stale (Jan 17 2026) — needs activity to unstale
      - Broad discussion about whether hotcue count column is the right approach vs a "prepared" state flag (daschuer, ronso0)
      - Potential pie chart icon instead of plain number (daschuer suggestion)
      - Related to hotcues-on-overview-waveform PR #15514 (acolombier suggested rendering hotcues in overview column instead)
      - Schema change v39→v40 — will conflict with other schema changes
      - Removed from integration: cross-thread SQLite crash (Qt::DirectConnection cuesUpdated lambda runs updateTrackHotcueCount on engine thread)
      - Crash fixed in branch: cuesUpdated now uses AutoConnection + DB-counting overload; CueDAO::updateTrackHotcueCount(TrackId) made public
    - Tested?: no
  - [x] **feature/2025.11nov.17-deere-channel-mute-buttons** - [#15624](https://github.com/mixxxdj/mixxx/pull/15624) - DRAFT - REVIEW_REQUIRED
    - Issue: [#15623](https://github.com/mixxxdj/mixxx/issues/15623)
    - Created: 2025-11-17, Last comment: 2026-02-15, Rebased: 2026-02-20, Updated: 2026-02-15
    - Next: On hold - marked as DRAFT by ronso0
    - Specifics:
      - Marked as DRAFT by ronso0 (Feb 9)
      - daschuer (Feb 9): "mute this PR until we have demand and good plan for this turntableist feature"
      - Needs visual feedback for mute state in Mixxx
      - daschuer suggests "unmute by cue" is more accurate term than "silent cue"
      - ronso0 questions necessity — "Why is the Vol fader not sufficient?"
      - daschuer suggests broader approach: knob widget with integrated kill/mute feature, explore Tremolo effect for "Transformer" effect
      - Needs stronger justification or pivot to the broader knob-with-kill approach
    - Tested?: yes
  - [x] **feature/2025.11nov.16-playback-position-control** - [#15617](https://github.com/mixxxdj/mixxx/pull/15617) - DRAFT - REVIEW_REQUIRED
    - Issue: [#14288](https://github.com/mixxxdj/mixxx/issues/14288)
    - Created: 2025-11-16, Last comment: 2026-02-09, Rebased: 2026-02-20, Updated: 2026-02-09
    - Next: Await review — clarified scope with daschuer/ronso0
    - Specifics:
      - daschuer (Feb 9): "this feature already exists" (pref option) — clarified: pref has no CO for runtime control
      - ronso0 confirmed: if it's about changing marker pos on the fly, the pref option has no CO
      - Adds `[Waveform],PlayMarkerPosition` ControlPotmeter (0.0–1.0) for runtime control
    - Tested?: no
  - [ ] **feature/2025.11nov.16-catalogue-number-column** - [#15616](https://github.com/mixxxdj/mixxx/pull/15616) - REVIEW_REQUIRED
    - Issue: [#12583](https://github.com/mixxxdj/mixxx/issues/12583)
    - Created: 2025-11-16, Last comment: 2026-02-15, Rebased: 2026-02-20, Updated: 2026-02-15
    - Next: Await review
    - Specifics:
      - acolombier left review comment 2026-02-14; replied 2026-02-15
      - Schema migration revision 40 — will conflict with hotcue-count branch (also schema change)
      - Removed from integration: schema change; keeping integration at upstream schema v40 until schema branches are stable
      - Uses MusicBrainz Picard tag mapping conventions
    - Tested?: no
  - [x] **feature/2025.05may.14-fivefourths** - [#14780](https://github.com/mixxxdj/mixxx/pull/14780) - DRAFT - REVIEW_REQUIRED
    - Issue: [#14686](https://github.com/mixxxdj/mixxx/issues/14686)
    - Created: 2025-05-14, Last comment: 2025-05-16, Rebased: 2026-02-20, Updated: 2026-02-08
    - Next: Update external manual, then await review
    - Specifics:
      - ~~Fix failing tests (Swiftb0y: "Next step would be to actually get the tests to pass")~~ done - BeatGridTest.Scale and BeatMapTest.Scale both pass
      - Update the Mixxx manual (acolombier request) - need to update external mixxxdj manual repo to document 5/4 BPM scaling
      - daschuer has no objections to the CO approach
      - Swiftb0y confirmed no performance implications from new COs
    - Tested?: yes
- 🔵 **Local Only (No PR)**
  - [ ] **feature/2026.02feb.17-mono-waveform-option**
    - Created: 2026-02-17, Rebased: none, Updated: 2026-02-17
    - Next: Implement mono waveform option for main deck waveforms
    - Specifics:
      - Add option to make main deck waveforms mono (L+R muxed, top-only rendering)
      - Similar to existing overview waveform mono feature
      - Add preference checkbox in waveform settings
      - Implement mono parameter in main waveform renderers
    - Tested?: no
  - [x] **feature/2025.10oct.14-waveform-hotcue-label-options**
    - Created: 2025-10-14, Rebased: 2026-02-20, Updated: 2026-01-30
    - Next: Maintain for personal use
  - [x] **feature/2025.10oct.08-utf8-string-controls**
    - Dependency for: hotcue-labelling, hotcue-label-options
    - Created: 2025-10-08, Rebased: 2026-02-20, Updated: 2026-01-30
    - Next: Maintain for personal use (not for upstream)
  - [x] **feature/2025.09sep.25-hotcue-labelling**
    - Created: 2025-09-25, Rebased: 2026-02-20, Updated: 2026-02-20
    - Next: Maintain for personal use
  - [x] **feature/2025.06jun.08-deere-deck-bg-colour**
    - Created: 2025-06-08, Rebased: 2026-02-20, Updated: 2026-01-30
    - Next: Maintain for personal use
  - [ ] **feature/2025.11nov.05-deere-waveform-zoom-deck-colors**
    - Created: 2025-11-05, Rebased: 2026-02-20, Updated: 2026-01-30
    - Next: Merge to integration, decide if PR-worthy
    - Specifics:
      - Evaluate if the Deere-specific waveform zoom deck color change is worth a PR or remains personal use
      - Test visual appearance across deck configurations
  - [ ] **draft/2025.10oct.21-tracker-module-stems**
    - Created: 2025-10-21, Rebased: none, Updated: 2025-10-21
    - Next: Continue development or archive
    - Specifics:
      - Depends on replace-libmodplug-with-libopenmpt (#15519) being accepted first
      - Adds stem support for tracker modules using libopenmpt
      - Not rebased — needs rebase before any work
  - [ ] **bugfix/2026.02feb.19-wglwidget-xcb-resize-gap** — ABANDONED
    - Created: 2026-02-19, Updated: 2026-02-19
    - Next: Archive or delete branch
    - Specifics:
      - Attempted WA_PaintOnScreen on WGLWidget to reduce XCB resize gap
      - Abandoned: WGLWidget lacks paintEngine(), WA_PaintOnScreen causes heap corruption abort
      - Gap is inherent to QOpenGLWindow+createWindowContainer; no viable fix
- ✅ **Merged to Upstream**
  - [x] ~~**bugfix/qt6-guiprivate-missing-component**~~ **RESOLVED** 2026-02-19 — fixed upstream, branch deleted
  - [x] ~~**feature/2025.11nov.05-waveform-cache-size-format**~~ - [#15578](https://github.com/mixxxdj/mixxx/pull/15578) **MERGED** 2026-02-16
  - [x] ~~**bugfix/2025.11nov.04-reloop-shift-jog-seek**~~ - [#15575](https://github.com/mixxxdj/mixxx/pull/15575) **MERGED** 2026-02-15
  - [x] ~~**bugfix/2025.11nov.16-reloop-beatmix-mk2-naming**~~ - [#15615](https://github.com/mixxxdj/mixxx/pull/15615) **MERGED** 2026-02-11
  - [x] ~~**bugfix/2025.11nov.04-fx-routing-persistence**~~ - [#15574](https://github.com/mixxxdj/mixxx/pull/15574) **MERGED** 2025-11-14

---

## TODO Summary

**Needs Attention (0 branches):** *(none)*

- **Awaiting Review (15 branches):**
  - **Feedback addressed, awaiting re-review**: restore-last-library-selection, controller-wizard-quick-access, stacked-overview-waveform, hide-unenabled-controllers
  - **Architecture changes needed**: replace-libmodplug-with-libopenmpt (daschuer wants DSP moved to effect rack)
  - **On hold (DRAFT)**: deere-channel-mute-buttons (marked draft Feb 9, needs broader plan)
  - **Recent activity**: hotcues-on-overview-waveform (stale Jan 19), library-column-hotcue-count (stale Jan 17)
  - **Clean PRs**: playback-position-control, catalogue-number-column, fivefourths (manual update needed), midi-makeinputhandler-null-engine, fix-learning-wizard-from-prefs-button (no PR yet), controlpickermenu-quickfx-deck-offset (track #16019)
  - **Abandoned (no PR)**: wglwidget-xcb-resize-gap (WA_PaintOnScreen causes heap corruption; gap is inherent)
- **Local Development (2 branches):**
  - **Decide PR-worthiness**: deere-waveform-zoom-deck-colors
  - **Continue or archive**: tracker-module-stems

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
    gh gist edit 5fb35c401736efed47ad7d78268c80b6 --filename INTEGRATION.md INTEGRATION.md
    ```

## Outline Format Reference
This section documents the structure of this file for AI assistants and future maintainers.

### Branch Entry Format
Branch naming convention: feature/YYYY.MMmon.DD-thing-descriptive-title

```markdown
- [x] **branch-name** - [#PR](url) - STATUS
  - Issue: [#ISSUE](url)
  - Optional description
  - Created: YYYY-MM-DD, Last comment: YYYY-MM-DD, Rebased: YYYY-MM-DD, Updated: YYYY-MM-DD
  - Next: Action item
  - Specifics:
    - Details about the branch and what probably should happen next
```

- `[x]` = merged to integration, `[ ]` = not merged
- Branch name in bold
- Issue link to related Mixxx issue/feature request (if applicable)
- Created date required for all branches
- Last comment date shows most recent PR comment ("none" if no comments), only for PRs
- Rebased date shows when branch was last rebased on `mixxxdj/mixxx` main ("none" if never)
- Updated date tracks last modification to branch
- Next action describes what needs to be done for this branch
- Within each section: `[x]` (integrated) branches first, then `[ ]` (not integrated) branches
- Within each group (`[x]` or `[ ]`), sort by updated date (newest first)
- STATUS is one of: DRAFT, REVIEW_REQUIRED, CHANGES_REQUESTED, MERGED, LOCAL_ONLY

### Section Order
1. Needs Attention (CHANGES_REQUESTED)
2. Open PRs (REVIEW_REQUIRED)
3. Local Only (No PR)
4. Merged to Upstream

### Summary Line
**When updating integration**: Update the "Last updated" date at the top of this file.

Update the summary line at the top when adding/removing branches:
```markdown
**Summary**: X need attention, Y awaiting review, Z merged upstream, W local-only
```