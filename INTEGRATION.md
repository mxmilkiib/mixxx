# Integration Test Configuration Prompt File

## Worktree Structure
- `~/src/mixxx/` is the root directory containing `.git` and worktree subdirectories
- `~/src/mixxx/integrated/` is the `integrated` branch with many feature merges
- Each feature/fix branch shall have its own worktree subdirectory until it is merged with mixxxdj/mixxx

## Workflow
- Keep the main and integrated branch synced with main of mixxxdj/mixxx
- Track feature branches created in worktree subdirectories below
- New feature/fix branches should be based upon the mixxxdj/mixxx main branch
- Branches marked [x] should all be merged to `integrated` branch
- Then the integrated branch should be built and tested, and based upon mixxxdj/mixxx main branch
- All development on feature and bugfix branches done in respective worktrees
- Update the `INTEGRATION.md` file when a branch is created or merged into the `integrated` branch
- Order branches by last updated date


The last time this was updated was on 2026-01-24

## Special Notes
- **UTF-8 string controls**: Local-only feature for mxmilkiib/mixxx, NOT for upstream PRs
- Feature branches for upstream PRs must NOT include UTF-8 commits

## Todo
- rebuild integrated branch with all feature branches
- address PR #15516 redundant stacked functions feedback
- PR #15574 merged (fx routing persistence fix)

## Branches
- [ ] feature/2025.11nov.17-deere-channel-mute-buttons
  - https://github.com/mixxxdj/mixxx/pull/15624
  - clean branch for upstream, 2025-11-17, 2025-11-20
- [ ] feature/2025.11nov.17-waveform-zoom-deck-colour
  - local only, 2025-11-17, 2025-11-17
- [ ] feature/2025.11nov.16-playback-position-control
  - https://github.com/mixxxdj/mixxx/pull/15617
  - clean branch for upstream, 2025-11-16, 2025-11-16
- [ ] feature/2025.11nov.16-catalogue-number-column
  - https://github.com/mixxxdj/mixxx/pull/15616
  - clean branch for upstream, 2025-11-16, 2025-11-16
- [ ] bugfix/2025.11nov.16-reloop-beatmix-mk2-naming
  - https://github.com/mixxxdj/mixxx/pull/15615
  - clean branch for upstream, 2025-11-16, 2025-11-16
- [ ] feature/2025.11nov.16-immediate-metadata-save
  - draft, 2025-11-16, 2025-11-16
- [x] feature/2025.11nov.05-hide-unenabled-controllers
  - https://github.com/mixxxdj/mixxx/pull/15580
  - clean branch for upstream, 2025-11-05, 2025-11-17
- [x] feature/2025.11nov.05-waveform-cache-size-format
  - https://github.com/mixxxdj/mixxx/pull/15578
  - clean branch for upstream, 2025-11-06, 2025-11-18
- [x] feature/2025.11nov.04-controller-wizard-quick-access
  - https://github.com/mixxxdj/mixxx/pull/15577
  - clean branch for upstream, 2025-11-05, 2025-11-16
- [x] bugfix/2025.11nov.04-reloop-shift-jog-seek
  - https://github.com/mixxxdj/mixxx/pull/15575
  - clean branch for upstream, 2025-11-04, 2025-11-17
- [x] feature/2025.10oct.20-restore-last-library-selection
  - https://github.com/mixxxdj/mixxx/pull/15460
  - clean branch for upstream, 2025-10-08, 2025-11-17
- [x] feature/2025.10oct.08-utf8-string-controls
  - **LOCAL ONLY** (not for upstream), merged to integration, 2025-10-08, 2025-10-08
  - used by: hotcue-labelling, hotcue-label-options
- [x] feature/2025.10oct.21-stacked-overview-waveform
  - https://github.com/mixxxdj/mixxx/pull/15516
  - merged to integration, 2025-10-21, 2025-10-21
- [x] feature/2025.10oct.21-replace-libmodplug-with-libopenmpt
  - https://github.com/mixxxdj/mixxx/pull/15519
  - merged to integration, 2025-10-25, 2025-11-22
- [x] feature/2025.10oct.20-hotcues-on-overview-waveform
  - https://github.com/mixxxdj/mixxx/pull/15514
  - merged to integration, 2025-10-20, 2026-01-19
- [x] feature/2025.10oct.17-library-column-hotcue-count
  - https://github.com/mixxxdj/mixxx/pull/15462
  - merged to integration, 2025-10-17, 2026-01-17
- [x] feature/2025.10oct.14-waveform-hotcue-label-options
  - https://github.com/mixxxdj/mixxx/pull/15462
  - merged to integration, 2025-10-14, 2025-10-14
- [x] feature/2025.09sep.25-hotcue-labelling
  - https://github.com/mixxxdj/mixxx/pull/15462
  - merged to integration, 2025-09-25, 2025-09-25
- [x] feature/2025.06jun.08-deere-deck-bg-colour
  - https://github.com/mixxxdj/mixxx/pull/15462
  - merged to integration, 2025-10-24, 2025-10-24
- [ ] feature/2025.05may.14-fivefourths
  - https://github.com/mixxxdj/mixxx/pull/14780
  - active development, 2025-11-13, 2025-11-13
- [ ] draft/2025.10oct.21-tracker-module-stems
  - draft, 2025-11-13, 2025-11-13
- [ ] draft/2025.10oct.16-waveform-height-control
  - draft, 2025-11-13, 2025-11-13
- [ ] draft/2025.10oct.16-sidebar-double-click-toggle
  - draft, 2025-11-13, 2025-11-13
- [ ] draft/2025.10oct.06-tracker-stems
  - draft, 2025-11-13, 2025-11-13
- [ ] draft/2025.10oct.06-mod-tracker-stems-render
  - draft, 2025-11-13, 2025-11-13
- [ ] draft/2025.10oct.06-library-sidebar-width-controls
  - draft, 2025-11-13, 2025-11-13