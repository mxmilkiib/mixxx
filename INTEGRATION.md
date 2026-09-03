# Mixxx Multi-PR Dev & Test Build (AI Integration Skill + State)

> Last updated: 2026-09-03
> URL: <https://gist.github.com/mxmilkiib/5fb35c401736efed47ad7d78268c80b6>
> [RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119)

## Basics

- **Purpose**: this living document is a prompt file that includes the rules and procedures, plus state, for an AI skill to manage multiple feature and bugfix branches for the testing and development of Mixxx, as well as a combined/integrated PR test build for dog-fooding changes
  - a script rebases all branches, builds test binaries, and runs the test suite.
  - **Last updated**: The "Last updated" date at the top of this file MUST be updated whenever this file is edited. It MUST remain as only a date.
  - **Gist sync**: `INTEGRATION.md` (this file), `mixxx-milkii-integration-update-branches.sh`, `mixxx-milkii-integration-pre-push.sh`, `mixxx-milkii-integration-gdb-run.sh`, `.github/workflows/mixxx-milkii-integration-manjaro-release.yml`, and `.github/workflows/mixxx-milkii-integration-auto-promote.yml` MUST be updated and synced to the Gist as the workflow evolves.

    ```bash
    gh gist edit 5fb35c401736efed47ad7d78268c80b6 --filename INTEGRATION.md INTEGRATION.md
    gh gist edit 5fb35c401736efed47ad7d78268c80b6 --filename mixxx-milkii-integration-update-branches.sh mixxx-milkii-integration-update-branches.sh
    gh gist edit 5fb35c401736efed47ad7d78268c80b6 --filename mixxx-milkii-integration-pre-push.sh mixxx-milkii-integration-pre-push.sh
    gh gist edit 5fb35c401736efed47ad7d78268c80b6 --filename mixxx-milkii-integration-gdb-run.sh mixxx-milkii-integration-gdb-run.sh
    gh gist edit 5fb35c401736efed47ad7d78268c80b6 --filename mixxx-milkii-integration-manjaro-release.yml .github/workflows/mixxx-milkii-integration-manjaro-release.yml
    gh gist edit 5fb35c401736efed47ad7d78268c80b6 --filename mixxx-milkii-integration-auto-promote.yml .github/workflows/mixxx-milkii-integration-auto-promote.yml
    ```

  - **This instance**: all file prefixes and the gist title currently in this instance MUST refer to user **"Milkii"** (user: change if this is not you)
  - **Cross-model review**: This document, the scripts, and the branch outline MUST be cross-checked against ground truth by a *different* model from the one that last wrote them, at least every several sessions or whenever a claim in the doc is questionable. Self-review by the authoring model reliably misses its own confabulations — status lines get carried forward, "auto-promoted" gets written for something never observed, dates get copied instead of queried. Anything the checking model cannot verify MUST be marked UNVERIFIED rather than left as an assertion.
    - **Model usage log**: Each model used to write or review this document MUST be recorded below with its first-use date and last-use date. A model's review record breaks when a different model starts being used — the new model gets its own entry. This log is the audit trail for the cross-model requirement.
      - **GLM-5.2 High** — first used: 2026-08-21, last used: 2026-09-03 (writing: manifest PR head fields, Personal Only section, auto gist sync, cross-model review tracking; branch cleanup: mono-waveform-option deletion, waveform-blend-customization deletion, invert-zoom-direction commit; libopenmpt: tracker DSP effect rack refactor, SoundSourceOpenMPT/TrackerEffect tests, PR #15519 closed and superseded by #16921; auto-promote workflow fix: force-update when from-scratch remerge diverges from previous integrated, correcting the fast-forward-only gate that blocked every promotion when upstream/main had moved)
    - **What to ask**
      - "what's the state of everything?"
      - "does the manifest and the outline match the current state?"
      - "do the process rules match what the associated scripts do?"
- **AI priming**: - this whole file is a prompt, and the user should do some things:
  - LLMs reward expertiese; be technical, know when you are asking a leading question or not
  - ask why the part of the codebase in question was originally made that way 
  - ask it to clean development cruft up before comitting
  - build test branches with debug symbols enabled
  - skip build tests if iteratively testing for one specific issue, and try running the build for a while for user testing
  - if Wayland, prefix test build paths presented to the user with "QT_QPA_PLATFORM=xcb"

## Authoritative Integration Manifest

> AI-generated section begins. Review this manifest before committing or running integration.

The JSON block below is the single source of truth for integration automation. The helper scripts MUST read it directly and MUST NOT duplicate branch lists, test exclusions, infrastructure paths, workflow identities, or package source pins. The status outline remains the source of human context and MUST agree with `integrate` values; `--validate-manifest` enforces that relationship and checks the registered worktrees.

<!-- MIXXX_INTEGRATION_MANIFEST_START -->
```json
{
  "schema": 1,
  "repository": "mxmilkiib/mixxx",
  "ci_workflow": "develop.yml",
  "ci_workflow_name": "Pull request or branch build",
  "release_workflow": "mixxx-milkii-integration-manjaro-release.yml",
  "branch_defaults": {
    "base": "upstream/main",
    "rebase": true,
    "test": true,
    "integrate": false,
    "gate": false,
    "dependencies": []
  },
  "branches": [
    {"ref": "feature/2025.10oct.08-utf8-string-controls", "worktree": "2025.10oct.08-utf8-string-controls", "integrate": true, "gate": true, "merge_order": 10},
    {"ref": "feature/2025.09sep.25-hotcue-labelling", "worktree": "2025.09sep.25-hotcue-labelling", "integrate": true, "gate": true, "dependencies": ["feature/2025.10oct.08-utf8-string-controls"], "merge_order": 20},
    {"ref": "feature/2025.10oct.14-waveform-hotcue-label-options", "worktree": "2025.10oct.14-waveform-hotcue-label-options", "integrate": true, "gate": true, "dependencies": ["feature/2025.10oct.08-utf8-string-controls"], "merge_order": 30},
    {"ref": "feature/2025.10oct.20-hotcues-on-overview-waveform", "worktree": "2025.10oct.20-hotcues-on-overview-waveform", "integrate": true, "gate": true, "merge_order": 40, "pr": 15514, "pr_head": "feature/hotcues-on-overview-waveform", "issue": 14994},
    {"ref": "feature/2026.08aug.28-library-overview-minute-markers", "worktree": "2026.08aug.28-library-overview-minute-markers", "integrate": true, "gate": true, "dependencies": ["feature/2025.10oct.20-hotcues-on-overview-waveform"], "merge_order": 41, "pr": 16967},
    {"ref": "feature/restore-last-library-selection", "worktree": "2025.10oct.20-restore-last-library-selection", "integrate": true, "gate": true, "merge_order": 50, "pr": 15460, "issue": 10125},
    {"ref": "feature/2025.10oct.21-replace-libmodplug-with-libopenmpt", "worktree": "2025.10oct.21-replace-libmodplug-with-libopenmpt", "integrate": true, "gate": true, "merge_order": 60, "pr": 16921, "issue": 9862, "supersedes_pr": 15519},
    {"ref": "feature/2025.10oct.21-stacked-overview-waveform", "worktree": "2025.10oct.21-stacked-overview-waveform", "integrate": true, "gate": true, "merge_order": 70, "pr": 15516, "pr_head": "feature/stacked-overview-waveform", "issue": 13265},
    {"ref": "feature/2025.11nov.04-controller-wizard-quick-access", "worktree": "2025.11nov.04-controller-wizard-quick-access", "integrate": true, "gate": true, "merge_order": 80, "pr": 15577, "issue": 12262},
    {"ref": "feature/2025.11nov.05-deere-waveform-zoom-deck-colors", "worktree": "2025.11nov.05-deere-waveform-zoom-deck-colors", "integrate": true, "gate": true, "merge_order": 90, "pr": 16874},
    {"ref": "feature/2025.11nov.05-hide-unenabled-controllers", "worktree": "2025.11nov.05-hide-unenabled-controllers", "integrate": true, "gate": true, "merge_order": 100, "pr": 15580, "issue": 14275},
    {"ref": "feature/2025.11nov.16-playback-position-control", "worktree": "2025.11nov.16-playback-position-control", "integrate": true, "gate": true, "merge_order": 110, "pr": 15617, "issue": 14288},
    {"ref": "feature/2025.11nov.17-deere-channel-mute-buttons", "worktree": "2025.11nov.17-deere-channel-mute-buttons", "integrate": true, "gate": true, "merge_order": 120, "pr": 15624, "issue": 15623},
    {"ref": "bugfix/2026.02feb.19-openglwindow-resize-repaint", "worktree": "2026.02feb.19-openglwindow-resize-repaint", "integrate": true, "gate": true, "merge_order": 130, "pr": 16012},
    {"ref": "bugfix/2026.02feb.19-textured-waveform-fbo-resize", "worktree": "2026.02feb.19-textured-waveform-fbo-resize", "integrate": true, "gate": true, "merge_order": 140, "pr": 16010},
    {"ref": "feature/2026.02feb.20-simple-waveform-top-and-overview", "worktree": "2026.02feb.20-simple-waveform-top-and-overview", "integrate": true, "gate": true, "merge_order": 150, "pr": 16021, "issue": 16020},
    {"ref": "bugfix/2026.02feb.21-hid-init-race-on-enumeration", "worktree": "2026.02feb.21-hid-init-race-on-enumeration", "integrate": true, "gate": true, "merge_order": 160, "pr": 16838},
    {"ref": "feature/2026.02feb.26-waveform-menu-order", "worktree": "2026.02feb.26-waveform-menu-order", "integrate": true, "gate": true, "merge_order": 170, "pr": 16046},
    {"ref": "bugfix/2026.05may.01-fix-timer-test-potmeter-clamping", "worktree": "2026.05may.01-fix-timer-test-potmeter-clamping", "integrate": true, "gate": true, "merge_order": 180},
    {"ref": "feature/2026.05may.03-extend-waveform-zoom-range", "worktree": "2026.05may.03-extend-waveform-zoom-range", "integrate": true, "gate": true, "merge_order": 190},
    {"ref": "feature/2025.10oct.17-library-column-hotcue-count", "worktree": "2025.10oct.17-library-column-hotcue-count", "pr": 15462, "pr_head": "feature/library-column-hotcue-count", "issue": 15461},
    {"ref": "feature/2025.11nov.16-catalogue-number-column", "worktree": "2025.11nov.16-catalogue-number-column", "pr": 15616, "issue": 12583},
    {"ref": "bugfix/2026.02feb.19-wayland-opengl-resize-warning", "worktree": "2026.02feb.19-wayland-opengl-resize-warning", "base": "upstream/2.6", "pr": 16014, "issue": 16013, "related_issues": [13814, 14492]},
    {"ref": "feature/2026.08aug.08-waveform-invert-zoom-direction", "worktree": "2026.08aug.08-waveform-invert-zoom-direction", "integrate": true, "gate": true, "merge_order": 200, "pr": 16928},
    {"ref": "feature/2026.08aug.22-library-waveform-uniform-time-base", "worktree": "2026.08aug.22-library-waveform-uniform-time-base", "integrate": true, "gate": true, "dependencies": ["feature/2026.08aug.28-library-overview-minute-markers"], "merge_order": 210, "pr": 16925},
    {"ref": "feature/2026.03mar.09-head-split-reverse", "worktree": "2026.03mar.09-head-split-reverse", "integrate": true, "gate": true, "merge_order": 215, "pr": 16137, "pr_head": "feature/head-split-reverse", "external": true, "issue": 14821},
    {"ref": "feature/2026.05may.31-waveform-zoom-controlpotmeter", "worktree": "2026.05may.31-waveform-zoom-controlpotmeter", "integrate": true, "gate": true, "merge_order": 220, "pr": 12387, "pr_head": "waveform-zoom-controlpotmeter", "external": true},
    {"ref": "feature/2026.08aug.23-deere-hotcue-count-selector", "worktree": "2026.08aug.23-deere-hotcue-count-selector", "rebase": false, "test": false, "pr": 16932},
    {"ref": "feature/2026.08aug.23-register-middle-side-button-events", "worktree": "2026.08aug.23-register-middle-side-button-events", "rebase": false, "test": false},
    {"ref": "feature/2026.08aug.23-register-middle-wheel-scroll", "worktree": "2026.08aug.23-register-middle-wheel-scroll", "rebase": false, "test": false, "dependencies": ["feature/2026.08aug.23-register-middle-side-button-events"]},
    {"ref": "latenight-16-hotcues-test", "worktree": "2026.08aug.24-latenight-16-hotcues-test", "rebase": false, "test": false}
  ],
  "test_exclusions": [
    "ControllerScriptEngineLegacyTest.*",
    "ControllerScriptEngineLegacyTimerTest.*",
    "AdjustReplayGainTest.AdjustReplayGainUpdatesPregain",
    "TrackMetadataExportTest.keepWithespaceKey",
    "MidiMappings/*",
    "HidMappings/*",
    "BulkMappings/*"
  ],
  "infrastructure_files": [
    ".github/workflows/mixxx-milkii-integration-auto-promote.yml",
    ".github/workflows/develop.yml",
    ".github/workflows/mixxx-milkii-integration-manjaro-release.yml",
    ".github/workflows/pre-commit.yml",
    "INTEGRATION.md",
    "mixxx-milkii-integration-gdb-run.sh",
    "mixxx-milkii-integration-pre-push.sh",
    "mixxx-milkii-integration-update-branches.sh"
  ],
  "package_sources": {
    "container": "manjarolinux/base@sha256:bbf1f1d746f28e138eea610e140d2f28cbb5b7c5da2fbff034b883527aa604e9",
    "taglib1": {"url": "https://aur.archlinux.org/taglib1.git", "commit": "f07fd925225ca1d9312b0f16746c65b1137f1eae"},
    "deere_redo": {"url": "https://github.com/mxmilkiib/deere-redo.git", "commit": "64b0c202d52b51088bec3abb819ece978c1c6c2b"},
    "launchpad_pro_mk3": {"url": "https://github.com/mxmilkiib/mixxx-novation-launchpad-pro-mk3-milkii.git", "commit": "593ba31c6781c7733b493a20a497d0771cec7d82"},
    "akai_mpd218": {"url": "https://github.com/mxmilkiib/mixxx-akai-mpd218-milkii.git", "commit": "7be5c2e248462d03bdfe96c2580e4ad21e7c7d5e"},
    "korg_nanokontrol2": {"url": "https://github.com/mxmilkiib/mixxx-korg-nanokontrol-2-milkii.git", "commit": "1d73e5cb04442e9a95145af210bf060816d5ba84"}
  }
}
```
<!-- MIXXX_INTEGRATION_MANIFEST_END -->

### Manifest Semantics

| Field | Meaning and invariant |
| --- | --- |
| `base` | Upstream ref used for commit-range checks and ordinary rebases. `upstream/main` by default; a branch targeting a release branch (e.g. `upstream/2.6`) MUST set this explicitly. The rebase pass rebases onto the declared base, not always `upstream/main`. Branches with a non-`main` base are excluded from the combined integration candidate unless their base is `upstream/main` |
| `dependencies` | Local refs that MUST appear earlier in the JSON array; the first dependency becomes the dependent branch's rebase target |
| `rebase` | Include the worktree in the bulk dependency-ordered rebase pass |
| `test` | Configure, build, and test this standalone worktree; independent of whether it enters the combined tree |
| `integrate` | Merge this ref into the combined candidate; MUST imply `rebase`, `test`, and `gate` |
| `gate` | Require a current clean build and test pass before pushing `integrating`; MUST NOT be true when `integrate` is false |
| `merge_order` | Unique integer ordering only for integrated refs; encodes overlapping-file relationships rather than relying on directory names |
| `test_exclusions` | The only local/package exclusion list; scripts derive GTest/CTest syntax from it |
| `infrastructure_files` | Paths restored from committed `integration` into every transactional candidate and protected from feature-branch pushes |
| `package_sources` | Full immutable container/source identities. Git repositories require 40-character commits; the container requires a SHA-256 digest |
| `pr` | Upstream PR number on `mixxxdj/mixxx`; enables `--validate-manifest` to verify the PR head ref matches the manifest |
| `pr_head` | Fork head branch name the PR actually watches, when it differs from `ref` (legacy undated branches). `--push-changed` pushes the local `ref` to `refs/heads/<pr_head>` so the PR receives content changes. When absent, the PR head is assumed to equal `ref` |
| `external` | `true` marks a branch tracking an upstream PR by another contributor (not mxmilkiib's own PR). The local ref is a cherry-pick of the PR's commits rebased onto `upstream/main` for integration dogfooding. `--push-changed` MUST NOT push external branches to origin — they are not our PRs to update |
| `issue` | Upstream issue number on `mixxxdj/mixxx` that the branch addresses. Informational; the outline remains the source of issue state and context |
| `related_issues` | Array of upstream issue numbers related to but not directly addressed by the branch. Informational |
| `supersedes_pr` | Upstream PR number that this branch supersedes (closed and replaced). Informational |
| workflow identity fields | Canonical CI filename/display name and release filename. GitHub trigger syntax cannot read the JSON at runtime, so validation MUST reject any static trigger that disagrees |

JSON array order is the rebase/dependency order. `merge_order` is separately authoritative for integration composition. A dormant WIP remains listed with `rebase: false` and `test: false`; removing its worktree MUST remove its manifest record in the same reviewed change.

> AI-generated section ends. The manifest is subject to human review.

## Rules 
- **Dual dir**: all source trees share the SAME `.git` database rooted at `~/src/mixxx/.git`.
  - `~/src/mixxx/` — checked out on `main`; synced with `mixxxdj/mixxx` main for testing upstream
  - `~/src/mixxx-dev/integration/` — checked out on `integration`; all `[x]`-marked branches merged here; script and helper files live here; this is where `./mixxx-milkii-integration-update-branches.sh` is run from;
  - `~/src/mixxx-dev/<branch>/` — individual feature/bugfix Git worktrees
  - Registered worktrees are not separate clones — `git log`, `git branch -a`, etc. show all branches from any path.
  - **Stability**: This dual setup SHOULD provide consistency for a stable bleeding-edge build without interference from local development.
- **Main sync**: The project repo MUST maintain a `main` branch that is synced with `mixxxdj/mixxx` main. `origin/main` MUST be kept as a fast-forward mirror of `upstream/main` — run `git push --no-verify origin main` after every `git fetch upstream && git merge upstream/main` on `main`.
  - **Main read-only**: The `main` branch MUST NOT receive any local commits — not INTEGRATION.md updates, not patches, nothing. All commits go on `integration` or a worktree branch. Any stray commits on `main` MUST be removed by force-pushing the clean `upstream/main` tip.
  - **Dev location**: All individual branch development SHOULD be done using the `mixxx-dev` worktree directory
  - **Rebase hygiene**: All branches SHOULD be kept up-to-date and rebased onto their manifest-declared `base` (typically `upstream/main`, but may be a release branch like `upstream/2.6`) to minimize merge conflicts, except merged branches
  - **Rebase first**: A branch MUST be rebased as an initial step before any new change is made to said branch
  - **Base tracking**: Each branch's upstream target (main vs a release branch) MUST be recorded in the manifest `base` field. The outline SHOULD note the base when it is not `upstream/main`. A branch targeting a release branch MUST NOT be merged into the main-based integration candidate — it would drag in the version↔main delta.
  - **"origin/main"** is "ours", **"upstream/main"** is "theirs" (mixxxdj/mixxx)

- **Worktrees**: All development MUST use worktrees, keeping individual branches compartmentalised and clean for upstream PRs.
  - **Branch tiers**: The `mixxx` repo MUST maintain three promotion-chain branches:
    - `integration` — the disposable combined candidate. A temporary detached worktree merges `upstream/main` and every manifest branch in `merge_order`; the checked-out branch changes only after the complete candidate succeeds.
    - `integrating` — the exact `integration` SHA after clean `RelWithDebInfo` builds and serial tests pass for every `gate` branch and for the combined tree itself.
    - `integrated` — the same SHA after the declared GitHub Actions workflow concludes `success`. Every failed, cancelled, skipped, stale, or timed-out CI run blocks promotion; whole jobs are never excused by name.
      - It is the only package source. Automatic promotion explicitly dispatches exact-SHA packaging because a ref update made with `GITHUB_TOKEN` cannot trigger a downstream `push` workflow.
      - `build/mixxx` here is the daily-driver binary.
  - **Manifest coverage**: Every date-prefixed worktree MUST appear exactly once in the authoritative manifest. Every `integrate: true` branch MUST have a matching `[x]` outline entry, existing ref, matching checked-out worktree, clean build stamp, and passing test sentinel. `--validate-manifest` blocks on drift.

- **Standalone branches**: Each feature/fix branch SHOULD work standalone without depending on other local branches (except where noted)
  - **Single-branch build**: When the user asks to build a specific branch or worktree, ALWAYS build the full `mixxx` executable (`cmake --build <worktree>/build --target mixxx`), NOT just `mixxx-test`. The test binary is built separately by the integration script; a user-requested build means they want a runnable binary. Build command: `CCACHE_BASEDIR=~/src/mixxx-dev/<name> nice -n 15 cmake --build ~/src/mixxx-dev/<name>/build --target mixxx -j$(nproc --ignore=2)`.
  - **Isolated test profiles**: When running a worktree build for manual testing, use `--settingsPath /tmp/mixxx-test-<branch-name>` to isolate config, library DB, and state from the main profile. Mixxx auto-creates the directory. Run: `<worktree>/build/mixxx --settingsPath /tmp/mixxx-test-<branch-name>`. Add `--controller-debug --developer` for diagnostic logging.

- **Outline currency**: The integration status outline MUST reflect the state of all branches, related issues, PRs, and dates, and MUST be updated after changes are committed — PR URLs SHOULD be checked first to catch new feedback
  - **User primacy**: The user will edit the outline and not the manifest. The AI MUST detect outline changes and thus update the manifest. If the AI updates the manifest, those changes MUST also be reflected in the outline for the user.
  - **Sections**: Feature and fix branches MUST be in the correct outline sections
  - **Issues**: Most branches MAY have related upstream issues; related issues SHOULD be listed in the outline
  - **Dates**: Dates for branch creation, last PR comment, and last update MUST be recorded in the status outline
  - **Dependencies**: Any fix or feature branch that relies on another local branch MUST be noted in the Branch Dependencies section
- **Non-interactive git**: Git operations MUST be non-interactive using `GIT_EDITOR=true` and `GIT_PAGER=cat` to avoid vim/editor prompts
- **File edits**: All file changes to tracked files MUST be made with the IDE's `edit`/`write_to_file` tools (showing diffs in the editor), NEVER via shell commands (`echo >`, `tee`, `sed -i`, etc.) which bypass the diff view entirely.

- **Clean commits**: A branch in `mixxx-dev` MUST have clean commits before first being linked with a GitHub PR
  - **Commit messages**: Commit messages MUST NOT be too verbose, and SHOULD be concise and descriptive.
  - **Code quality**: Code quality MUST be verified before pushing — code MUST be proper, straight to the point, robust, and follow Mixxx coding style. This is achieved with a pre-commit hook to check the style of the code.
  - **History**: Feature/fix branch history MUST NOT be rewritten (no squash, no interactive rebase) without explicit permission from Milkii. "Complete" means the upstream PR has been merged or the branch has been deliberately closed. The integration branch MAY have merge commits.
  - **Incremental PRs**: Changes to `mixxxdj/mixxx` PRs MUST be incremental so as to be easy to review, and MUST NOT completely reformulate a system in a single commit
  - **Secondary patches**: Secondary patches are small fixes that either (a) resolve a residual problem that only became visible after a larger fix landed, or (b) are a prerequisite that a main fix branch depends on. They MUST be tracked in the **Secondary Patches** section of the outline, with a `Depends-on` or `Resolves-residual-from` note linking them to the related primary branch
  - **Secondary patch upstream**: A secondary patch SHOULD be submitted upstream independently if it stands alone; if it only makes sense in context of the primary fix, it MAY be folded into that PR

- **Branch compartmentalisation**:
  - **CRITICAL**: `mixxx-dev/` worktrees MUST only contain commits belonging to their named feature.
    - MUST NOT commit INTEGRATION.md, integration merge commits, or unrelated fixups into a fix or feature worktree
    - INTEGRATION.md MUST NOT be committed to any feature branch in `mixxx-dev/`
    - Before making any edit in `mixxx-dev/`, the active worktree MUST be confirmed to match the intended branch:

  ```bash
  git -C ~/src/mixxx-dev/<worktree>/ branch --show-current
  ```

  - To verify a worktree is clean (only its own commits ahead of upstream/main or its declared base):

  ```bash
  git -C ~/src/mixxx-dev/<worktree>/ log --oneline <declared-base>..HEAD
  ```

  - If a worktree has accumulated cruft, inspect and preserve any recoverable work first. A hard reset or force-update is destructive and requires explicit permission for that specific branch:
    - No real feature commits yet: after confirmation, reset to the manifest-declared base.
    - Real commits mixed with cruft: rebase only the feature commits onto the declared base, then request permission before force-updating any published ref.
  - **MUST ALWAYS create new feature branches from `upstream/main` (or the declared release branch base), never from local `main`** — defence-in-depth: if `main` ever accumulates stray commits (violating Main read-only), branching from the upstream ref guarantees a clean base:

  ```bash
  git fetch upstream
  git worktree add ~/src/mixxx-dev/<name> -b feature/<branch-name> upstream/main
  # For a release-branch-targeted PR:
  git worktree add ~/src/mixxx-dev/<name> -b bugfix/<branch-name> upstream/2.6
  ```

  - **Before committing WIP in any worktree**, verify the branch is correct AND that the diff contains only changes belonging to that feature:

  ```bash
  git -C ~/src/mixxx-dev/<worktree>/ diff --stat
  git -C ~/src/mixxx-dev/<worktree>/ branch --show-current
  ```

  - **If WIP from another feature is present in a worktree**, stash it before committing:

  ```bash
  git -C ~/src/mixxx-dev/<worktree>/ stash push --include-untracked -m "<description of what it is and where it belongs>"
  ```

  - **Before opening or updating a PR**, verify the branch contains only its own commits relative to `upstream/main` (not local `main`):

  ```bash
  git log --oneline feature/<branch-name> --not upstream/main
  ```


- **PR cues**:
  - **Head branch identity**: The local branch checked out in a worktree MUST be the same ref name as the head branch of its upstream PR. If they differ, `--push-changed` pushes a branch nobody is reviewing and the PR silently rots. Verify with `gh pr view <n> --repo mixxxdj/mixxx --json headRefName`.
  - **Legacy mismatched PRs**: Three early PRs were opened from undated fork branches while local development moved to dated refs. The manifest records both `pr` (PR number) and `pr_head` (the fork branch the PR watches) for these. `--validate-manifest` checks that `gh pr view <pr> --json headRefName` still equals `pr_head`; drift is reported. `--push-changed` pushes the local `ref` to `refs/heads/<pr_head>` so the PR receives content changes without needing to close and reopen. GitHub does not allow changing the head branch of an open PR, so the undated fork branch is kept as a mirror of the dated ref. (#15519 was the fourth legacy PR but was closed 2026-08-22 and superseded by #16921, which uses the dated ref directly.)
  - **Future prevention**: New branches created with the date-prefix policy have `ref == pr_head` and need no `pr_head` field. The `pr` field MAY be declared for any branch with an upstream PR so validation can verify head identity automatically.
  - **Personal-only**: Some features (UTF-8 string controls) MUST NOT be submitted to `mixxxdj/mixxx` upstream as they are for personal use only
  - **Push permission**: Permission MUST be sought from the user before pushing commits to GitHub. Once the user has confirmed a push in a session, further pushes in that same session MAY proceed without asking again, to reduce friction.
  - **Pre-push hook installation**: All worktrees share the hook directory under `~/src/mixxx/.git`. The untracked `.git/hooks/pre-push` file MUST be a thin executable delegate that preserves Git's stdin and arguments. It tries the worktree's own copy of the versioned script first (so `integration`/`integrating`/`integrated` use their committed copy), then falls back to the `integration` worktree copy for feature branches that do not carry infrastructure:

  ```bash
  #!/bin/bash
  # Thin delegate — logic lives in mixxx-milkii-integration-pre-push.sh (committed on
  # the integration branch). Falls back to the integration worktree copy when
  # pushing from a branch that does not carry the script (e.g. integrated/main).
  HOOK_SCRIPT="$(git rev-parse --show-toplevel)/mixxx-milkii-integration-pre-push.sh"
  if [[ ! -x "$HOOK_SCRIPT" ]]; then
      HOOK_SCRIPT="${HOME}/src/mixxx-dev/integration/mixxx-milkii-integration-pre-push.sh"
  fi
  exec "$HOOK_SCRIPT" "$@"
  ```

    - The versioned hook reads Git's ref-update records from stdin. MUST NOT pipe into the delegate or invoke it manually without equivalent input.
    - Integration infrastructure is allowed only when the destination ref is `integration`, `integrating`, or `integrated`. A feature branch on the personal fork is still an upstream PR source, so the hook MUST block infrastructure there too.
    - Before every non-delete push, the hook checks changed C++ lines across every pushed old→new range, then REQUIRES a configured `RelWithDebInfo` build, a successful incremental `mixxx-test` rebuild, a clean tracked tree, resolvable shared libraries, and a passing filtered suite.
  - **Pre-push hook timeout**: The hook runs `timeout 420 ./mixxx-test` to prevent indefinite hangs. If the timeout fires, it blocks the push. Investigate the hanging test in isolation first (`./mixxx-test --gtest_filter=SuiteName`); passing alone indicates state poisoning from an earlier test.

- **"Updating" the system**: When the user asks to "update" or "run integration", or says the system has been updated, this MUST include all of the following stages strictly from top to bottom. MUST NOT skip forward to build or push after a failed precondition.

- **Stage 1 — Review and commit pending integration infrastructure changes** before starting. `remerge_integration` refuses tracked changes because its pre-reset commit is the transaction's infrastructure source. Commits and pushes remain deliberate human actions under `AGENTS.md`.
  - Run `./mixxx-milkii-integration-update-branches.sh --validate-manifest` first. It MUST confirm the JSON structure, outline `[x]` entries, worktree inventory, checked-out refs, bases, dependencies, merge order, full source pins, and infrastructure list.
- **Stage 2 — Promotion check**: At the start of any session, verify the exact-SHA invariant:
  - `integrated` MUST never be ahead of `origin/integrating`. Verify with `git rev-list --left-right --count origin/integrating...origin/integrated`; a non-zero right-hand count is a gate violation. Divergence (both counts non-zero) is expected when a new from-scratch remerge candidate is pending promotion; promotion force-updates `integrated` to the tested SHA.
  - Manual promotion queries only the manifest-declared workflow, branch, push event, and exact current `origin/integrating` SHA. It fetches again before promotion and aborts if the branch moved.
  - Automatic promotion receives the tested SHA from `workflow_run`, requires a `success` conclusion, confirms `integrating` still equals it, and updates `integrated` — force-updating when the from-scratch remerge diverges from the previous `integrated`. It then dispatches the manifest-declared release workflow with that SHA.
  - **Why exact SHA matters**: querying only the latest branch run can return the previous successful run before GitHub registers the new one, allowing untested code through. Delayed or rerun events can also target an old SHA. Both promotion paths therefore bind workflow, event type, branch, tested SHA, current remote SHA, and promoted SHA.
  - **No failure allowlist**: job names reveal where a failure occurred, not why. A Windows job with a known flaky test can later fail because the code no longer compiles; treating the whole job as infrastructure would hide that regression. Cancelled, timed-out, stale, neutral, skipped, startup-failed, or failed runs all block promotion.
  - **Workflow chaining**: GitHub suppresses `push` workflows caused by `GITHUB_TOKEN`. Auto-promote MUST call the release workflow with `workflow_dispatch`; rerunning auto-promote checks for an existing successful or active package run before dispatching another.
  - Infrastructure MUST travel through `integration` → `integrating` → `integrated`; direct commits to `integrated` are forbidden.
  - Empty auto-promote history means "never ran", not "working". Check with `gh run list --workflow mixxx-milkii-integration-auto-promote.yml --repo mxmilkiib/mixxx --limit 1 --json status,conclusion`.
- **Stage 3 — Integration freshness check**: Run `--remerge-integration`. It always constructs the desired manifest composition from scratch, so removed branches and changed merge order cannot survive a stale ancestor-only check. `--remerge-integration --dry-run` builds the candidate and reports the merge list and resulting SHA without installing it — useful for checking conflict surface before committing to a real remerge; the rerere cache it populates is reused by the subsequent real run.
- **Stage 4 — Build and test identity**: Every selected worktree and the combined `integration` tree MUST have a clean successful build stamp and matching passing test sentinel. Both bind HEAD, `CMakeCache.txt`, test-binary mtime, linked-library metadata, and manifest hash. Dirty trees, missing or updated linked libraries, changed configuration, failed builds, changed exclusions, or moved HEADs invalidate the gate. `--build-all-tests` performs an incremental build of every selected tree; `--run-tests` runs invalidated suites serially.
- **Stage 5 — Fetch upstream/main and sync**
  - `git fetch upstream && git rev-list --left-right --count upstream/main...main`;
  - if the left count is non-zero, `main` is behind upstream and MUST be fast-forwarded and pushed to `origin`. If the right count is non-zero, `main` has stray commits (violates Main read-only): stop, show them, preserve anything recoverable, and request explicit permission before any hard reset or force-push.
  - **Branch merged** Check all `[x]` branches: for each, verify whether its commits are already present in `upstream/main` (`git log upstream/main --oneline | grep <keyword>`); if fully merged, move the entry to the "Merged to Upstream" section, remove the `[x]` marker, and record the merge date — MUST be done BEFORE rebasing or rebuilding so merged branches are excluded from both
- **Stage 6 — Review-state refresh**: Check all open PRs for new review feedback (`CHANGES_REQUESTED`, new comments) and update INTEGRATION.md statuses accordingly.
  - `gh pr view <PR-number>`
  - `gh pr list --repo mixxxdj/mixxx --author mxmilkiib`
- **Stage 7 — Validate + rebase + transactional remerge + exact build + serial test + push** — run `--rebase-merge-test-push` from `~/src/mixxx-dev/integration/`.
  - The manifest order is topological: dependency roots are rebased first, and a dependent rebases onto its declared dependency rather than blindly onto `upstream/main`.
  - Remerge happens in a temporary detached worktree. A conflict, failed infrastructure restore, or interruption leaves the checked-out `integration` branch unchanged and disables rerere before returning. There is no partial-build or "continue without remerge" route.
  - Every phase is fatal. Neither `integration` nor `integrating` is pushed after a failed rebase, merge, build, or test.
  - `--rebase-merge-test-push-promote` additionally waits for CI on the exact pushed SHA and promotes `integrated` only after strict success.
  - After tests pass, the pipeline also builds the main `mixxx` executable for the integration worktree so one has a runnable local binary at `~/src/mixxx-dev/integration/build/mixxx`.
  - **Quick integration**: When one only needs **a runnable integration binary without local tests or remote operations**, run `--quick-integration` instead of the full Stage 7. It rebases all branches, transactionally remerges, and builds both `mixxx-test` and `mixxx` for the integration tree only, skipping per-branch builds, local tests, pushes, CI, and promotion. Use this for fast iteration between full pipeline runs.
  - **Personal-only backup**: Committed personal-only branches SHOULD be pushed to `origin` for off-machine backup. Pushing a branch ref cannot back up uncommitted working-tree changes.
  - **Monitoring progress**: `mixxx-milkii-integration-update-branches.sh --rebase-merge-test-push` (or `--rebase-merge-test-push-promote`) writes timestamped phase/branch updates to `STATUS_FILE=/tmp/mixxx-integration-status`. In a second terminal: `tail -f /tmp/mixxx-integration-status`. Individual test suite logs: `tail -f /tmp/mixxx-test-logs/<worktree>.log`. During test runs, a heartbeat prints test count every 30 s to the main terminal so it never appears frozen. During CI polling (`--promote-integrated` or `--rebase-merge-test-push-promote`), the exact run ID, status, conclusion, SHA, and elapsed time are reported; use `gh run view <id> --repo mxmilkiib/mixxx` for per-job detail.
- **Stage 8 — CI-conscious feature-branch pushing**:
  - feature branch force-pushes to `origin` trigger full CI matrix on `mixxxdj/mixxx`.
  - a pure rebase (same patch, different base) has zero CI value — it wastes shared runner time and annoys reviewers who monitor PR activity.
  - so rebased branches MUST NOT be automatically pushed
  - if any PR branches have actual content changes (review feedback addressed, conflict resolutions), run `--push-changed`. It compares stable patch IDs relative to each branch's manifest-declared base, so a pure rebase is skipped while a changed conflict resolution is pushed.
  - manual pushes (e.g. after addressing review feedback) MAY bypass this — push directly from the worktree as needed.
  - **Conflict resolution**: When resolving merge conflicts — whether during rebases or integration merges — conflicts MUST be carefully resolved and the operation continued non-interactively. Common issues:
    - Schema revisions: increment version numbers
    - Enum IDs in `trackmodel.h`: assign unique IDs
    - Header declarations vs implementations: keep both sides' additions
  - MUST update "Rebased" and "Updated" dates in the outline to today.
  - Branches with unresolved conflicts SHOULD be noted for later attention.
- **Stage 9 — Update INTEGRATION.md after the run**:
  - Update the top `Last updated` date, outline summary counts, per-branch rebased/updated dates derived from commands, unresolved conflicts, review state, and CI/package status.
  - MUST NOT copy dates or success claims from an older revision. Anything not verified from Git, GitHub, or a test artifact is `UNVERIFIED`.
  - If worktree participation, merge order, a base, dependency, exclusion, infrastructure path, workflow identity, or package source changed, the manifest MUST be updated first and `--validate-manifest` rerun.
  - Sync every listed integration file to the Gist. `--rebase-merge-test-push` and `--rebase-merge-test-push-promote` call `sync_gist` automatically after a successful run; `--sync-gist` syncs on demand. Local edits are not deployed automation, and Gist upload is not Git branch deployment.
- **Merge Order**: for Overlapping Source Files
  - Some active branches modify the same source files. Their authoritative `merge_order` values MUST preserve these relationships; filesystem order is irrelevant and MUST NOT control merges:
    - **`src/waveform/renderers/waveformoverviewrenderer.cpp` and `.h`** — 4 branches touch these:
      - 1. `2025.10oct.20-hotcues-on-overview-waveform` (adds hotcue rendering to overview)
      - 2. `2026.08aug.28-library-overview-minute-markers` (adds minute marker rendering, depends on hotcues)
      - 3. `2025.10oct.21-stacked-overview-waveform` (adds StackedRGB enum + renderer)
      - 4. `2026.02feb.20-simple-waveform-top-and-overview` (adds Simple overview type)
  - Each builds on the previous — merging out of order will cause conflict resolutions that silently drop changes.
    - **`src/preferences/dialog/dlgprefwaveform.cpp`** — 4 branches touch this:
      - 1. `2025.10oct.21-stacked-overview-waveform` (adds Stacked to combobox)
      - 2. `2026.02feb.20-simple-waveform-top-and-overview` (adds Simple to top of combobox)
      - 3. `2026.02feb.26-waveform-menu-order` (reorders combobox via kValues, removes sort lambda)
      - 4. `2026.05may.03-extend-waveform-zoom-range` (extends zoom range entries)
    - **`waveform-menu-order`** MUST merge after **`simple-waveform`** — the manifest enforces this explicitly.
    - **`src/library/library.cpp`, `src/library/sidebarmodel.cpp`, `src/library/sidebarmodel.h`** — only `restore-last-library-selection` touches these. The transactional remerge always starts from the current branch ref, so a rewritten branch cannot leave a stale prior merge in the candidate.
- **Integration remerge** — automated by `--rebase-merge-test-push` and available alone as `--remerge-integration`.
  - **Schema exclusion**: Schema-changing branches MUST remain `integrate: false` until their revisions are compatible.
  - A detached temporary worktree starts at `upstream/main`, merges the manifest's `integrate: true` refs by `merge_order`, and restores exactly the manifest's `infrastructure_files` from the original committed `integration` SHA.
  - The real `integration` worktree MUST be clean and remains untouched until the candidate is complete. The candidate is then installed with one local reset. Failed or interrupted transactions clean their temporary worktree and disable rerere.
  - **No cherry-pick**: MUST ALWAYS merge branch refs. Cherry-picks duplicate commits and hide branch provenance.
  - Rerere is enabled only inside the temporary merge transaction and disabled on every return path; feature rebases never inherit integration conflict resolutions.
  - **Infrastructure preservation**: `upstream/main` does not contain the personal workflows, this document, or helper scripts, and upstream versions of `develop.yml`/`pre-commit.yml` do not contain the fork-specific changes. The transaction restores every path in `infrastructure_files` from the original committed `integration` SHA before installing the candidate. A missing path is fatal.
  - **Conflict policy**: Feature branches MUST stay suitable for standalone upstream review. Compatibility needed only when branch B is combined with branch A belongs in the integration merge and its rerere resolution, not in B's PR commits. Genuine branch defects MUST remain fixed on the branch itself.
  - A conflict MUST NOT be followed by build or promotion. The temporary merge is aborted and removed, the real branch remains unchanged, and the conflicting relationship MUST be resolved before rerunning the whole transaction.
  - **Dry run**: `--remerge-integration --dry-run` performs every step through candidate resolution but skips the final `reset --hard`, leaving `integration` at its original SHA. The rerere cache is still written, so a following real run reuses recorded resolutions. Side effects are limited to the temp worktree, the `rerere.enabled` config toggle, and `rr-cache`.
  - `integration` and `integrating` are reconstructed refs and therefore use `--force-with-lease`; `integrated` is promotion-only — both manual and automatic promotion force-update when the from-scratch remerge diverges from the previous `integrated`.
  - A full reconfigure is REQUIRED only when branches add CMake files or sources:

    ```bash
    cmake -B ~/src/mixxx-dev/integration/build -S ~/src/mixxx-dev/integration -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCCACHE_SUPPORT=ON
    ```

  - The common incremental build is:

    ```bash
    CCACHE_BASEDIR=~/src/mixxx-dev/integration nice -n 15 cmake --build ~/src/mixxx-dev/integration/build --target mixxx -- -j$(nproc --ignore=2)
    ```

- **Build type**: All worktree builds MUST use `CMAKE_BUILD_TYPE=RelWithDebInfo`. Debug builds abort on `DEBUG_ASSERT` calls, causing tests to crash with non-zero exit that looks like a test failure (e.g. `SoundSourceProxyTest.openEmptyFile` firing `FileInfo::canonicalLocation` assert). Release builds suppress the crash but lose debug symbols. `RelWithDebInfo` is the correct balance. Check: `grep CMAKE_BUILD_TYPE <worktree>/build/CMakeCache.txt`. Reconfigure with: `cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo <worktree>/build`.
  - **Build parallelism**: NEVER launch multiple full worktree builds simultaneously — 5 × `-j$(nproc)` on a 32-core machine means 150 competing jobs and effectively no progress. Worktree builds MUST be run serially using `-j$(nproc --ignore=2)`. With ccache + CCACHE_BASEDIR correctly set, each subsequent build is mostly cache hits making serial runs fast.
  - **Killing builds**: `pkill -f cmake` only kills the cmake wrapper — ninja/make/cc1plus children survive and saturate the CPU. To kill a full build tree: `ps aux | grep -E 'cc1plus|ninja|/usr/bin/make' | grep -v grep | awk '{print $2}' | xargs -r kill -9`. In the script, Ctrl-C triggers a `kill 0` trap that kills the whole process group cleanly.
  - **ccache**: All worktree builds MUST be configured with `-DCCACHE_SUPPORT=ON`. Cache size SHOULD be 15 GB or more. To enable on an existing build: `cmake -DCCACHE_SUPPORT=ON <worktree>/build` (in-place reconfigure).
    - **Cross-worktree sharing requires `CCACHE_BASEDIR`**: worktrees are at different paths, so preprocessor `#line` markers embed different absolute paths in the hash. Setting `CCACHE_BASEDIR=<worktree-root>` at build time strips that prefix, making paths relative — identical upstream files then produce the same hash across worktrees. This is set automatically by `mixxx-milkii-integration-update-branches.sh`; manual builds MUST also set it: `CCACHE_BASEDIR=~/src/mixxx-dev/<name> cmake --build ...`.
    - `hash_dir = false` in `~/.config/ccache/ccache.conf` prevents the build directory path from entering the hash (complementary to CCACHE_BASEDIR). Both settings are REQUIRED for robust cross-worktree sharing.
- **Manifest selection**: `rebase`, `test`, `integrate`, and `gate` are independent manifest booleans. This replaces `SKIP_BRANCHES` and filesystem-discovery policy. A dirty or intentionally dormant WIP can remain documented with `rebase: false` and `test: false` without silently entering a gate.
- **Exact build and test completeness**:
  - Missing build trees are configured in parallel. Every selected `mixxx-test`, including `integration/build/mixxx-test`, is then built serially with `-j$(nproc --ignore=2)` and `CCACHE_BASEDIR`.
  - A clean successful build writes `<name>.built`; a passing serial test writes `<name>.tested`. Both contain the exact HEAD, binary mtime, CMake cache hash, linked-library metadata hash, and manifest hash. Only an exact `pass` is accepted. There are no `dirty-pass` or `nocommits` exceptions.
  - `push_integrating` checks every `gate: true` branch and the combined tree again. An old executable left behind by a failed build cannot satisfy the gate.
  - The separate outline field `Tested?:` means manual testing by Milkii on real DJ hardware; automated sentinels never change it.
  - Test exclusions exist only in the manifest. The update script, pre-push hook, and package workflow read them directly. Removing or adding an exclusion changes the manifest hash and invalidates prior test sentinels.
  - Local and package tests MUST run serially because concurrent `mixxx-test` processes share audio mocks, the ControlObject registry, timers, and SQLite test state.
  - GitHub Actions CI promotion is strict: the complete declared workflow MUST conclude `success`. A flaky or infrastructure failure MUST be rerun or fixed; a job name MUST NOT convert failure into success.
  - `--promote-integrated` and automatic promotion both bind the CI run, branch tip, and promoted ref to one SHA.
- **Test Exclusion Rationale**
  - The manifest list is authoritative; these explanations record why each blind spot currently exists. An exclusion MUST be removed after its upstream cause is verified fixed, and a new exclusion MUST NOT be added merely to obtain a green run.
    - `ControllerScriptEngineLegacyTest.*`: `softTakeover_setParameter` hangs in the headless environment, and neighbouring tests can leave shared ControlObject state behind.
    - `ControllerScriptEngineLegacyTimerTest.*`: `coTimerId` was a `ControlPotmeter` capped at 50 while real QTimer IDs are much larger. Clamping creates ID collisions; `beginTimer_repeatedTimer` can poison later mapping tests. The local fix is tracked by `bugfix/2026.05may.01-fix-timer-test-potmeter-clamping`. Filter the whole suite, not only `singleShot*`.
    - `AdjustReplayGainTest.AdjustReplayGainUpdatesPregain`: consistently segfaults in the headless local/package environment; it remains a specific test exclusion, never an excuse for an entire platform job.
    - `TrackMetadataExportTest.keepWithespaceKey`: `getKeyText()` returns the internal `B_FLAT_MINOR` spelling instead of the expected display text `B♭m`.
    - `MidiMappings/.*`, `HidMappings/.*`, and `BulkMappings/.*`: parameterised fixtures load every bundled controller XML and initialise JavaScript engines. Residual timer/ControlObject state can hang a later fixture; `Pioneer_CDJ_350_Ch2_midi_xml` was one observed stopping point. The three suites share the same fixture lifecycle, so filtering only one family is not reliable.
  - The clean-room GitHub CI workflow is not converted to success by this list. Only the local pre-push/integration suite and Manjaro package test read these exclusions; strict CI still decides promotion.
- **Manjaro/Arch Release Pipeline**
  - **Default branch**: The fork default is `integrated` because the auto-promote `workflow_run` listener MUST exist on the default branch. `main` remains a read-only `upstream/main` mirror. Verify rather than assume this repository setting.
  - **Upstream release workflow**: The fork's inherited `release.yml` remains disabled because a mirrored `main` push MUST NOT launch Mixxx's publishing matrix without upstream secrets.
  - **Exact source gate**:
    - A normal human push to `integrated` triggers packaging.
    - Automatic promotion explicitly calls `workflow_dispatch` with `expected_sha`; GitHub suppresses downstream push workflows for changes made with `GITHUB_TOKEN`.
    - Manual dispatch MUST use the exact current `integrated` SHA. The manifest job checks out that SHA and compares it with `refs/heads/integrated`; selecting another branch MUST NOT change the packaged source.
  - **Manifest job**: A small Ubuntu job checks out `expected_sha`, confirms the remote `integrated` ref still equals it, parses this document, and exports the container digest, test regex, and every external URL/commit. The build job consumes those outputs; workflow actions themselves are pinned to full commits in the workflow file.
  - **Build environment**:
    - Runner: `ubuntu-24.04`; build container: the digest-pinned `package_sources.container`, without `--privileged`.
    - `pacman -Syu` intentionally follows current rolling Manjaro packages, so source inputs are pinned but repository binaries are not bit-for-bit reproducible.
    - Base tools: `base-devel`, Git, CMake, Ninja, and ccache. Mixxx dependencies include protobuf, vamp-plugin-sdk, chromaprint, libid3tag, rubberband, soundtouch, LAME, Ogg/Vorbis, MAD, MP4v2, FAAD2, Opus, WavPack, libshout, libsndfile, PortMidi, PortAudio, SQLite, UPower, Lilv, libebur128, libopenmpt, Qt 6 modules, Microsoft GSL, hidapi, FFmpeg, FFTW, FLAC, GLU, PipeWire/JACK, libusb, jsoncpp, GoogleTest, and GoogleMock.
    - A non-root `builder` runs both `makepkg` operations and has no sudo permission. The workflow installs completed packages as root in a separate step.
  - **Pinned AUR dependency**:
    - `taglib1` is absent from the Manjaro repositories. Its AUR Git commit is authoritative in `package_sources.taglib1`; the workflow MUST verify the detached checkout before running `makepkg`.
    - `utf8cpp`, `cppunit`, and zlib are installed for its build/check dependencies. PGP/checksum verification MUST NOT be bypassed.
  - **CMake configuration**:
    - `CMAKE_BUILD_TYPE=RelWithDebInfo`, `QT6=ON`, `QML=ON`, `BULK=ON`, `FFMPEG=ON`, `LOCALECOMPARE=ON`, `MAD=ON`, `MODPLUG=OFF`, `OPENMPT=ON`, `WAVPACK=ON`, `BATTERY=ON`, `BROADCAST=ON`, `DOWNLOAD_MANUAL=ON`, `HID=ON`, `KEYFINDER=ON`, `LILV=ON`, `OPUS=ON`, `QTKEYCHAIN=ON`, and `VINYLCONTROL=ON`.
    - User udev-rule installation is disabled; warnings and debug assertions are non-fatal for packaging. C and C++ both use ccache.
    - Cache path `/ccache`, 5 GB limit, `hash_dir=false`, exact-SHA save key, and prefix restore fallback.
  - **Tests**: CTest uses a 45-second per-test timeout, `--parallel 1`, failure output, and exactly the manifest exclusions. Parallel compilation is MAY; parallel tests MUST NOT.
  - **Pinned personal resources**:
    - Deere-Redo, Launchpad Pro MK3, Akai MPD218, and Korg nanoKONTROL2 repositories are checked out detached at their manifest commits and verified before selected files are copied into staging.
    - Changing a pin MUST review the old-to-new commit diff, change this manifest, and allow the manifest hash to invalidate prior local test sentinels.
  - **Package construction**:
    - CMake installs into a staging `DESTDIR`. Runtime linked libraries are mapped to owning packages with `ldd` and `pacman -Qo`; runtime-loaded plugins not visible to `ldd` remain covered by the explicit dependency installation above.
    - Generated identity: `pkgname=mixxx-milkiib-integrated-manjaro`, `pkgver=<major.minor>_<UTC timestamp>_<short SHA>`, `pkgrel=1`, `arch=('x86_64')`, `conflicts=('mixxx' 'mixxx-git')`, `provides=('mixxx')`, and unstripped debug symbols.
    - The staged `/usr/local` tree is relocated into the package's `/usr` tree. A package build failure MUST be fatal; no release MUST be created.
  - **Release and provenance**:
    - Pre-release tag: `mixxx-milkiib-integrated-<UTC timestamp>-<short SHA>`. The release remains explicitly unsigned and intended for personal integration testing.
    - Attachments are the package, its SHA-256 file, and a provenance file recording exact Mixxx SHA, `git describe`, container digest, AUR commit, skin commit, and controller commits.
  - **Concurrency**: Newer packaging cancels an older in-progress package build. This intentionally keeps only the newest daily-driver package when promotions arrive quickly. Packaging remains asynchronous after promotion; inspect it with `gh run list --workflow mixxx-milkii-integration-manjaro-release.yml --repo mxmilkiib/mixxx`.
  - **Retention**: The workflow does not prune old prereleases or tags. Deleting either MUST be a separate destructive operation requiring explicit permission.
- **Worktree Branch Hygiene**
  - **Upstream-resolved cleanup**: If an upstream commit (by any contributor) fully resolves the problem a local branch was addressing — rendering the local branch redundant or superseded — the branch entry MUST also be moved to the "Merged to Upstream" section and marked **RESOLVED** (not MERGED), with a note identifying the upstream commit or PR that resolved it. The worktree MUST then be pruned per the **Worktree pruning** rule.
  - **Upstream verification before closing**: Before closing or marking a PR/branch as RESOLVED, the fix MUST be verified by reading the actual code in `upstream/main` and `upstream/2.[latest-major]` — `git show upstream/main:path/to/file.cpp | grep -A N "function"`. A verbal claim that the fix is upstream is NOT sufficient. If verification fails, the PR MUST NOT be closed.
  - **Worktree pruning**: When a branch is merged upstream, closed, or abandoned, its manifest entry and `[x]` marker MUST first be removed in the same reviewed infrastructure change, then its worktree MUST be removed.
    - The local branch ref MAY be deleted only with explicit permission.
    - `--validate-manifest` MUST intentionally fail while either the document or disk inventory still contains only one side of the change.
    - **Merged cleanup**: Move the outline entry to "Merged to Upstream" and record the upstream commit or PR.

## Dev Helper Scripts

| Script | Purpose |
| --- | --- |
| `mixxx-milkii-integration-update-branches.sh` | Parses and validates this document; performs dependency-aware rebases, transactional ordered remerge, exact build/test stamping for branches plus the combined tree, content-aware pushes, local gating, exact-SHA CI polling, and exact-SHA promotion (force-update when diverged) |
| `mixxx-milkii-integration-pre-push.sh` | Reads exclusions and protected paths from this document; blocks integration infrastructure on every non-tier destination, requires formatting, incrementally rebuilds `mixxx-test`, rejects dirty/stale trees, and runs tests |
| `mixxx-milkii-integration-gdb-run.sh` | Runs Mixxx non-interactively under GDB with debuginfod, forwards additional arguments, returns the inferior's exit status, collects crash diagnostics conditionally, and retains timestamped logs |

### Integration Helper Modes

| Invocation | Contract |
| --- | --- |
| no option | Validate, fetch upstream, and rebase every `rebase: true` worktree in manifest dependency order; never push |
| `--validate-manifest` | Parse JSON, validate defaults/dependencies/order/pins, compare `[x]` outline state, require exact worktree/ref/base/file coverage, and verify PR head identity via `gh pr view` for branches declaring `pr` |
| `--remerge-integration` | Build and install one complete transactional combined candidate; never build or push |
| `--remerge-integration --dry-run` | Build the candidate in the temp worktree and report the resulting SHA and merge list, but skip the final `reset --hard`; `integration` ref is left unchanged. Rerere cache is still populated, so a subsequent real run reuses recorded resolutions |
| `--build-all-tests` / `--rebuild-tests` | Configure missing selected trees in parallel, then incrementally build every selected branch and the combined tree serially; write exact build stamps |
| `--run-tests` | Run only tests whose exact build signature lacks a current pass; never accept a dirty tree |
| `--push-changed` | Push only `rebase: true` branches whose stable patch IDs differ from their fork refs; pushes to `pr_head` when declared (legacy undated PR heads); pre-push checks still apply |
| `--push-integrating` | Recheck every `gate: true` branch and the combined tree, then force-with-lease the exact `integration` SHA to `integrating` |
| `--promote-integrated` | Poll only the declared push workflow for exact `origin/integrating`, require success and an unchanged ref, then update `integrated` (force-update when diverged) |
| `--rebase-merge-test-push` | Run the complete local pipeline; every phase is fatal; syncs Gist after success |
| `--rebase-merge-test-push-promote` | Run the local pipeline, wait for exact-SHA CI, promote after success; syncs Gist after success |
| `--quick-integration` | Rebase, transactional remerge, build `mixxx-test` and `mixxx` for the integration tree only; skip local tests and all remote operations (push, CI, promotion). Use for fast iteration when one only needs a runnable integration binary |
| `--sync-gist` | Sync every infrastructure file to the Gist on demand; non-fatal on failure |

### Runtime State

- `~/.cache/mixxx-integration/<name>.built`: `<HEAD> <mixxx-test mtime> <CMakeCache hash> <linked-library metadata hash> <manifest hash>`.
- `~/.cache/mixxx-integration/<name>.tested`: the same signature followed by `pass` or `fail`.
- `~/.cache/mixxx-integration/tests-passed`: combined integration SHA, manifest hash, and passing-tree count for audit only; per-tree sentinels remain authoritative.
- `/tmp/mixxx-integration-status`: append-only phase and branch progress for `tail -f`.
- `/tmp/mixxx-test-logs/<name>.log`: latest complete output for each test tree.

### GDB Helper Details

- Executable search order: `integration/build/mixxx`, `$PWD/mixxx`, then `~/src/mixxx/build/mixxx`.
- Default Mixxx arguments: `--developer --controller-debug --debug-assert-break`; caller arguments are appended without flattening or re-parsing.
- GDB runs with pagination and confirmations disabled, pretty printing enabled, debuginfod enabled, and `SIG32`, `SIGPIPE`, `SIGUSR1`, and `SIGUSR2` ignored.
- A signalled stop records a full backtrace, registers, and all-thread backtraces. A normal exit skips unavailable stack commands. `--return-child-result` makes the shell status describe Mixxx rather than merely GDB command processing.
- Logs are named `mixxx_gdb-<user>_<YYYYMMDD_HHMMSS>.log` beside the helper and retained for both clean and failed runs.

---

## Outline Format Reference

This section documents the structure of this file for AI assistants and future maintainers.

### Summary Line

Update the summary line when adding/removing branches. Every branch is counted exactly once, in the
section it appears in — do not count a schema-excluded branch again under review-required:

```markdown
**Summary** (verified YYYY-MM-DD; each branch counted once): A changes-addressed · B review-required · C changes-requested-open · D schema-excluded · E local-only/abandoned/archived · F personal-only · G secondary patches · H merged/resolved upstream · I untracked WIP worktree


### Section Order
1. 🔴 Awaiting Review from Others — a reviewer owes us a response and no change request is outstanding
2. 🟠 Changes Addressed — Awaiting Re-review — we answered a change request; GitHub may still report CHANGES_REQUESTED until re-review
3. 🔧 Secondary Patches
4. 🐛 Bug Fixes — Open PRs
5. 🟡 New Features — Open PRs
6. 🟤 External PRs (Testing) — upstream PRs by other contributors, cherry-picked for integration dogfooding; never pushed to origin
7. ⚠️ Schema-Changing Branches (Excluded from Integration)
8. 🔵 Local Only (No PR) — undecided WIP, archived, or abandoned branches with no PR
9. 🟣 Personal Only (No PR, deliberately not for upstream) — deliberately personal-use features that will not be submitted upstream
10. ✅ Merged to Upstream / Archived

Sections 1 and 2 are distinct: 1 means the ball is in a reviewer's court from the start, 2 means it
was in ours and we passed it back. `CHANGES_ADDRESSED` is a local status with no GitHub equivalent —
`reviewDecision` will keep saying `CHANGES_REQUESTED` until someone re-reviews, so the two MUST NOT be
treated as contradictory. Record both: the local judgement and the raw `reviewDecision`.


### Branch Entry Format
Branch naming convention: feature/YYYY.MMmon.DD-thing-descriptive-title

```markdown
- [x] **branch-name** - [#PR](url) - STATUS
  - Issue: [#ISSUE](url) (OPEN|CLOSED <reason> <date>)
  - Optional description
  - Created: YYYY-MM-DD, Last comment: YYYY-MM-DD (author), Last review: YYYY-MM-DD (author, STATE), Rebased: YYYY-MM-DD, Updated: YYYY-MM-DD
  - Next: Action item
  - Specifics:
    - Details about the branch and what probably should happen next
```

- `[x]` = `integrate: true` in the authoritative manifest, `[ ]` = not integrated. Validation fails if the active outline and manifest disagree.
- Branch name in bold, and it MUST be the real ref name — check with `git -C <worktree> branch --show-current`, not the worktree directory name, which may carry a date prefix the branch does not
- Issue link to related Mixxx issue/feature request (if applicable), with its open/closed state — a closed driving issue changes whether the branch is still worth pursuing
- Created date required for all branches
- Last comment date is the most recent *issue comment* ("none" if none), with its author. Reviews are separate: a `CHANGES_REQUESTED` review is not a comment and will not show up in the comments list. Record both, from `gh pr view <n> --json comments,reviews`
- Rebased date shows when branch was last rebased on `mixxxdj/mixxx` main ("none" if never). If the PR head is a different ref, say so — the local ref being rebased does not rebase the PR
- Updated date tracks last modification to branch
- Next action describes what needs to be done for this branch
- Every date in an entry MUST come from a command, not from the previous version of this file. Carried-forward dates are the single most common defect found in cross-model audits
- Within each section: `[x]` (integrated) branches first, then `[ ]` (not integrated) branches
- Within each group (`[x]` or `[ ]`), sort by updated date (newest first)
- STATUS is one of: DRAFT, REVIEW_REQUIRED, CHANGES_REQUESTED, MERGED, RESOLVED, LOCAL_ONLY, PERSONAL_ONLY, ARCHIVED
  - DRAFT: PR is a draft, not ready for review
  - REVIEW_REQUIRED: PR is open and awaiting first review
  - CHANGES_REQUESTED: reviewer has requested changes that have not yet been addressed
  - CHANGES_ADDRESSED: reviewer requested changes, changes have been made, awaiting re-review (no reviewer comment since the changes were pushed)
  - MERGED: PR has been merged into `mixxxdj/mixxx`
  - RESOLVED: no PR, or PR closed because the problem was resolved upstream by another contributor
  - LOCAL_ONLY: no PR, exists only locally with no decided upstream/personal status yet (e.g. uncommitted or undecided WIP)
  - PERSONAL_ONLY: no PR, personal-use feature that has been deliberately decided will not be submitted upstream
  - ARCHIVED: branch/PR abandoned or shelved indefinitely; worktree removed
- Secondary patch entries use `Resolves-residual-from` or `Depends-on` instead of `Issue` to link to the primary branch

---

## Branch Dependencies

```text
utf8-string-controls (PERSONAL_ONLY)
├── hotcue-labelling (PERSONAL_ONLY)
└── hotcue-label-options (PERSONAL_ONLY)
```

Branches with dependencies on personal-only branches cannot be submitted upstream as-is. They MUST be refactored to remove the dependency or the dependency MUST be upstreamed first.

## Branch and Integration Status Outline

**Summary** (verified 2026-08-25; each branch counted once): 7 changes-addressed · 7 review-required · 1 changes-requested-open · 2 schema-excluded · 7 local-only/abandoned/archived · 3 personal-only · 2 secondary patches · 2 external-testing · 10 merged/resolved upstream · 0 untracked WIP worktree

- 🔴 **Awaiting Review from Others**
  - none
- 🟠 **Changes Addressed — Awaiting Re-review**
  - [x] **feature/restore-last-library-selection** - [#15460](https://github.com/mixxxdj/mixxx/pull/15460) - CHANGES_ADDRESSED
    - Worktree: `~/src/mixxx-dev/2025.10oct.20-restore-last-library-selection/` (dir is dated, branch ref is not — branch matches the PR head, so pushes land correctly)
    - Issue: [#10125](https://github.com/mixxxdj/mixxx/issues/10125) (OPEN)
    - Created: 2025-10-08, Last comment: 2026-08-08 (mxmilkiib), Last review: 2025-11-17 (ronso0, CHANGES_REQUESTED), Rebased: 2026-08-20, Updated: 2026-08-20
    - Local HEAD 57aa59b4f5 · origin/PR head e322da90bd — rebased-only since last push, patch identical, nothing to push
    - Next: Redone as two commits, confirmed working — awaiting re-review; mxmilkiib left update comment 2026-08-08
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
  - [x] **feature/2025.11nov.16-playback-position-control** - [#15617](https://github.com/mixxxdj/mixxx/pull/15617) - DRAFT - CHANGES_ADDRESSED
    - Issue: [#14288](https://github.com/mixxxdj/mixxx/issues/14288) (OPEN)
    - Created: 2025-11-16, Last comment: 2026-02-09 (mxmilkiib), Last review: 2026-05-15 (ronso0, CHANGES_REQUESTED), Rebased: 2026-08-20, Updated: 2026-08-20
    - Next: Await re-review — ronso0 CHANGES_REQUESTED (2026-05-15) recorded as addressed 2026-05-26, but no comment or push is visible on the PR after 2026-02-09 and `reviewDecision` is still CHANGES_REQUESTED — UNVERIFIED, confirm before treating as addressed; CI failures are pre-existing flaky (Flatpak aarch64 network timeout, macOS x64 BeatsTranslateTest SEGFAULT — unrelated to our changes)
    - Specifics:
      - daschuer (Feb 9): "this feature already exists" (pref option) — clarified: pref has no CO for runtime control
      - ronso0 confirmed: if it's about changing marker pos on the fly, the pref option has no CO
      - Adds `[Waveform],PlayMarkerPosition` ControlPotmeter (0.0–1.0) for runtime control
    - Tested?: no
  - [x] **feature/2025.11nov.04-controller-wizard-quick-access** - [#15577](https://github.com/mixxxdj/mixxx/pull/15577) - CHANGES_ADDRESSED
    - Issue: [#12262](https://github.com/mixxxdj/mixxx/issues/12262) (OPEN)
    - Created: 2025-11-04, Last comment: 2026-02-18 (mxmilkiib), Last review: 2025-11-16 (ronso0, CHANGES_REQUESTED), Rebased: 2026-08-20, Updated: 2026-08-20
    - Note: rebased with wmainmenubar.cpp/h conflict resolved (Controller+KeyboardEventFilter both included)
    - Next: Awaiting re-review — ronso0 CHANGES_REQUESTED (Nov 16) addressed Feb 18; fix-learning-wizard folded in Feb 22 (ffc28f8)
    - Specifics:
      - ~~devicesChanged not updating menu post-startup~~ fixed — connected to mappingApplied
      - ~~range-for style on m_controllerPages~~ done
      - fix-learning-wizard folded in: emit mappingStarted() before show() so prefs dialog hides before wizard appears
    - Tested?: yes
  - [x] **feature/2025.11nov.05-hide-unenabled-controllers** - [#15580](https://github.com/mixxxdj/mixxx/pull/15580) - CHANGES_ADDRESSED
    - Issue: [#14275](https://github.com/mixxxdj/mixxx/issues/14275) (OPEN)
    - Created: 2025-11-05, Last comment: 2026-08-03 (mxmilkiib), Last review: 2025-11-17 (ronso0, COMMENTED), Rebased: 2026-08-20, Updated: 2026-08-20
    - Next: Awaiting re-review — ronso0 Nov 17 feedback addressed Feb 28: removed redundant null checks, confirmed rename already done; GitHub `reviewDecision` is REVIEW_REQUIRED (no outstanding change request)
    - Specifics:
      - ~~Rename "unenabled" to "disabled" everywhere — config keys, function names, and UI text (ronso0)~~ done
      - ~~Remove unnecessary null checks on tree items — always valid post-construction (ronso0)~~ done
    - Tested?: yes
  - [x] **feature/2026.02feb.26-waveform-menu-order** - [#16046](https://github.com/mixxxdj/mixxx/pull/16046) - CHANGES_ADDRESSED
    - Created: 2026-02-26, Last comment: none (no issue comments), Last review: 2026-05-26 (daschuer, CHANGES_REQUESTED), Rebased: 2026-08-20, Updated: 2026-08-20
    - Next: Await re-review — addressed daschuer: removed lambda + alphabetical sort; order now set via `kValues` in `waveformwidgettype.h`
    - Specifics:
      - Reorders `kValues` in `WaveformWidgetType`: Simple, Filtered, HSV, RGB, Stacked, VSyncTest
      - Removes alphabetical combobox sort from `DlgPrefWaveform` — factory order is display order
      - Old: Simple, Filtered, HSV, VSyncTest, RGB, Stacked → New: Simple, Filtered, HSV, RGB, Stacked, VSyncTest
    - Tested?: yes (1203 tests pass)
  - [x] **feature/2025.10oct.21-stacked-overview-waveform** - [#15516](https://github.com/mixxxdj/mixxx/pull/15516) - DRAFT - CHANGES_ADDRESSED
    - **PR head repointed** 2026-08-21: fork branch `feature/stacked-overview-waveform` force-pushed to match the dated ref. The manifest declares `pr_head` so `--push-changed` keeps them in sync going forward.
    - Issue: [#13265](https://github.com/mixxxdj/mixxx/issues/13265) (OPEN)
    - Created: 2025-10-21, Last comment: 2026-02-17 (mxmilkiib), Last review: 2025-11-01 (mxmilkiib, COMMENTED), Rebased: 2026-08-20 (local ref only), Updated: 2026-08-20
    - Next: Repoint the PR head — push the dated branch to `origin/feature/stacked-overview-waveform` after reviewing the diff, or close and reopen from the current ref. Then re-request review to unstale; no new reviewer feedback since the naming comment (Feb 17).
    - Specifics:
      - ~~Remove redundant Stacked HSV and Stacked LMH renderers~~ done
      - ~~Remove unnecessary `static_cast<int>`~~ done
      - ~~Rename "Stacked (RGB)" to "Stacked"~~ done
      - All feedback addressed
      - Left comment 2026-02-17 re: Filtered/Stacked naming confusion — see #15996
    - Tested?: yes
  - [ ] **bugfix/2026.02feb.19-wayland-opengl-resize-warning** - [#16014](https://github.com/mixxxdj/mixxx/pull/16014) - CHANGES_ADDRESSED
    - Issue: [#16013](https://github.com/mixxxdj/mixxx/issues/16013) (CLOSED 2026-02-21 as completed — the PR still adds the warning, but the issue no longer justifies it; check whether the PR is still wanted), related [#13814](https://github.com/mixxxdj/mixxx/issues/13814) (OPEN), [#14492](https://github.com/mixxxdj/mixxx/issues/14492) (OPEN)
    - Created: 2026-02-19, Last comment: 2026-08-03 (daschuer), Rebased: 2026-08-03, Updated: 2026-08-03
    - Base: `upstream/2.6`; the manifest rebases and tests it against that base but excludes it from the main-based combined tree and promotion gate
    - Next: Await review — rebased onto 2.6 per daschuer, daschuer CHANGES_REQUESTED addressed 2026-08-03, marked ready for review
    - Note: NOT in integration merges — branch now targets upstream/2.6, merging into main-based integration would drag in the 2.6↔main delta
    - Specifics:
      - Wayland + QOpenGLWindow subsurface resize causes synchronous compositor buffer realloc on every pixel of drag
      - Workaround: QT_QPA_PLATFORM=xcb (XWayland)
      - Adds qWarning at startup when Wayland detected with OpenGL waveforms and spinny widgets
      - Warning fires once per session (static flag), not per OpenGLWindow construction
      - Detection uses `startsWith("wayland")` to cover Qt5 variants (wayland-egl, wayland-generic, wayland-xcomposite-egl, wayland-xcomposite-glx)
      - MIXXX_USE_QOPENGL guard removed per daschuer — getSurfaceFormat callers are already GL-gated
      - References issues #16013 (slow resize), #14492 (sticky mouse on waveform) and #13814 (resize mouse defocus, GLSL types)
    - Tested?: yes (1174 tests pass on 2.6 base, 2026-08-03; stale pre-rebase mixxx-test binary was hanging the pre-push hook — rebuilt)
- 🔧 **Secondary Patches**
  - [x] **bugfix/2026.05may.01-fix-timer-test-potmeter-clamping** — upstream test bug
    - Created: 2026-05-01, Rebased: 2026-08-20
    - No PR (upstream or fork) exists — the "Next" below has been outstanding since 2026-05-01
    - coTimerId ControlPotmeter max=50 clamped QTimer IDs (10000+ in full suite); replaced with ControlObject
    - Next: open upstream PR to mixxxdj/mixxx
    - Workaround: pre-push hook and script filter `ControllerScriptEngineLegacyTimerTest.*` (entire suite — `beginTimer_repeatedTimer` corrupts clamped-ID-50 state, causing `MidiMappings` JS tests to hang; filtering only `singleShot*` is insufficient), `ControllerScriptEngineLegacyTest.*` (softTakeboard state poisoning), `MidiMappings/.*`/`HidMappings/.*`/`BulkMappings/.*` (MappingTestFixture hangs from residual state poisoning even with Legacy suites filtered — observed: `Pioneer_CDJ_350_Ch2_midi_xml`), and `TrackMetadataExportTest.keepWithespaceKey` (`getKeyText()` returns `B_FLAT_MINOR` internal string instead of `B♭m` display format, fails in all worktrees). Remove filters once upstream fix lands.
  - [x] **bugfix/2026.02feb.21-hid-init-race-on-enumeration**
    - Created: 2026-02-21, Rebased: 2026-08-20, Updated: 2026-08-20
    - Note: originally tracked as residual from midi-makeinputhandler (#16003, merged upstream 2026-06-18) — stands alone
    - PR: [#16838](https://github.com/mixxxdj/mixxx/pull/16838) — REVIEW_REQUIRED, opened 2026-08-04
    - Next: Await review on #16838
    - Merged into integration: 2026-08-05 (mutex fix merged — conflict in hidenumerator.cpp comment resolved)
    - Specifics:
      - The hidraw backend of hidapi is not thread-safe; `hid_open()`/`hid_open_path()` internally call `hid_enumerate()` → `udev_enumerate_scan_devices()`
      - Upstream PR #15692 (Joerg, `loadHidReportDescriptorAtEnumeration2`) made each `HidController` constructor spawn a `QtConcurrent::run` background thread in `fetchReportDescriptorInBackground()` that calls `hid_open*`
      - With 3+ HID devices (Launchpad Pro MK3, MPD218, BeatMix4) those background threads race inside udev, corrupting the heap — manifests as `free(): chunks in smallbin corrupted` from an unrelated `free()` later (e.g. library scanner `RecursiveScanDirectoryTask` destructor)
      - Fix part 1: call `hid_init()` explicitly on the main thread in `HidEnumerator::queryDevices()` before `hid_enumerate()` and before any `HidController` objects are constructed
      - Fix part 2 (added 2026-08-05): guard the `hid_open*` calls in `fetchReportDescriptorInBackground()` with a global `std::mutex s_hidOpenMutex` so only one background fetch thread touches udev at a time — `hid_init()` alone was insufficient
    - Tested?: yes (crash no longer reproduced; library scan completes cleanly, 33091 tracks)
- 🐛 **BUG FIXES - Open PRs (REVIEW_REQUIRED)**
  - [x] **bugfix/2026.02feb.19-textured-waveform-fbo-resize** - [#16010](https://github.com/mixxxdj/mixxx/pull/16010) - REVIEW_REQUIRED
    - Worktree: `~/src/mixxx-dev/2026.02feb.19-textured-waveform-fbo-resize/` (created 2026-08-20)
    - Created: 2026-02-19, Last comment: 2026-05-21 (stale-bot), Last review: none, Rebased: 2026-08-20, Updated: 2026-08-20
    - Next: Await review
    - Specifics:
      - Improved: defer FBO reallocation to paintGL via m_pendingResize flag
    - Tested?: yes
  - [x] **bugfix/2026.02feb.19-openglwindow-resize-repaint** - [#16012](https://github.com/mixxxdj/mixxx/pull/16012) - DRAFT - REVIEW_REQUIRED
    - Worktree: `~/src/mixxx-dev/2026.02feb.19-openglwindow-resize-repaint/` (created 2026-08-20)
    - Created: 2026-02-19, Last comment: 2026-05-21 (stale-bot), Last review: none, Rebased: 2026-08-20, Updated: 2026-08-20
    - Next: Await review
    - Specifics:
      - Restores m_dirty flag: defers extra paintGL+swapBuffers from resizeGL to next vsync
      - Does not fix Wayland resize lag (compositor-level issue)
    - Tested?: yes
- 🟡 **NEW FEATURES - Open PRs (REVIEW_REQUIRED)**
  - [x] **feature/2025.11nov.05-deere-waveform-zoom-deck-colors** - [#16874](https://github.com/mixxxdj/mixxx/pull/16874) - REVIEW_REQUIRED
    - Created: 2025-11-05, Rebased: 2026-08-20, Updated: 2026-08-20
    - Next: Await review
    - Specifics:
      - Sets WaveformZoomContainer background to DeckBackgroundColor (was hardcoded #333333)
      - Changes zoom button icon fills from #d2d2d2 to #000000 for visibility on deck-colored background
      - Removes hardcoded background-color from style.qss (now set via XML BgColor)
      - Deere-only change, 5 files, 4 insertions / 4 deletions
    - Tested?: yes (2026-08-10)
  - [x] **feature/2026.05may.03-extend-waveform-zoom-range** — No PR yet
    - Created: 2026-05-03, Rebased: 2026-08-20, Updated: 2026-08-20
    - Next: Test, then open upstream PR
    - Specifics:
      - Extends `s_waveformMinZoom` from 1.0 → 0.5 (allows 200% zoom-in, twice as detailed)
      - Extends `s_waveformMaxZoom` from 10.0 → 80.0 (allows 1.25% zoom-out, 8× more overview)
      - Fixes `DlgPrefWaveform` combo box to handle sub-1.0 zoom entries without integer cast div-by-zero
      - Index↔zoom mapping generalised via `subOneCount` offset
    - Tested?: no
  - [x] **feature/2026.02feb.20-simple-waveform-top-and-overview** - [#16021](https://github.com/mixxxdj/mixxx/pull/16021) - CHANGES_REQUESTED
    - Issue: [#16020](https://github.com/mixxxdj/mixxx/issues/16020) (OPEN)
    - Created: 2026-02-20, Last comment: 2026-05-28 (mxmilkiib, stale-bot reset), Last review: 2026-05-29 (daschuer, CHANGES_REQUESTED), Rebased: 2026-08-20, Updated: 2026-08-20
    - Next: Address daschuer upgrade-path issue — RGB selected before update becomes Simple after; default should remain RGB; likely combobox position stored instead of enum value
    - Specifics:
      - Adds Simple as an overview waveform type (amplitude envelope, signal color, stereo mirrored)
      - Moves Simple to top of overview waveform combobox
      - daschuer CHANGES_REQUESTED: upgrade path alters waveform selection — RGB becomes Simple after update
      - ninomp inline: unused StackedRGB enum entry — mxmilkiib confirmed cruft from branch overlap
    - Tested?: yes (2026-07-16)
  - [x] **feature/2026.08aug.28-library-overview-minute-markers** - [#16967](https://github.com/mixxxdj/mixxx/pull/16967) - REVIEW_REQUIRED
    - Created: 2026-08-28, Updated: 2026-08-28
    - Next: Await review
    - Specifics:
      - Adds minute marker rendering to library overview waveform, gated on existing `draw_overview_minute_markers` preference
      - Markers drawn proportionally at 60s intervals as 2px white lines at top and bottom
      - Depends on hotcues-on-overview branch for TrackPointer API and trackDurationMillis plumbing
      - 3 files, 76 insertions / 41 deletions across `waveformoverviewrenderer.cpp/.h`, `overviewcache.cpp`
    - Tested?: no
  - [x] **feature/2026.08aug.22-library-waveform-uniform-time-base** - [#16925](https://github.com/mixxxdj/mixxx/pull/16925) - REVIEW_REQUIRED
    - **Branch rebased** 2026-08-28: now depends on `feature/2026.08aug.28-library-overview-minute-markers` instead of main; passes `drawMinuteMarkers=false` to renderer when uniform is on; `redrawMinuteMarkersUniform` gated on preference; SQL duration query replaced with `pTrack->getDuration()`
    - Created: 2026-08-22, Last comment: none, Last review: none, Updated: 2026-08-28
    - Next: Await review
    - Specifics:
      - Adds `[Waveform],overview_uniform_time_base` control and `[Waveform],overview_time_base_minutes` preference (default 6.0 min) so all library overview waveforms share the same pixels-per-second ratio; short tracks occupy less than the full column width, long tracks are clipped
      - When uniform is on, proportional minute markers from renderer are skipped and `redrawMinuteMarkersUniform` redraws them at exact pixel positions; both paths gated on `draw_overview_minute_markers`
      - 7 files, 230 insertions / 18 deletions across `overviewcache.cpp/.h`, `overviewdelegate.cpp/.h`, `dlgprefwaveform.cpp/.h`, `dlgprefwaveformdlg.ui`
    - Tested?: yes (2026-08-22)
  - [x] **feature/2026.08aug.08-waveform-invert-zoom-direction** - [#16928](https://github.com/mixxxdj/mixxx/pull/16928) - REVIEW_REQUIRED
    - Created: 2026-08-08, Last comment: none, Last review: none, Rebased: 2026-08-20, Updated: 2026-08-23
    - Next: Await review
    - Specifics:
      - Adds invert zoom direction preference for waveform mouse wheel (4 files, 42 insertions / 12 deletions across `dlgprefwaveform.cpp/.h`, `dlgprefwaveformdlg.ui`, `wwaveformviewer.cpp`)
    - Tested?: yes (2026-08-21)
  - [x] **feature/2025.10oct.21-replace-libmodplug-with-libopenmpt** - [#16921](https://github.com/mixxxdj/mixxx/pull/16921) - REVIEW_REQUIRED
    - Supersedes [#15519](https://github.com/mixxxdj/mixxx/pull/15519) (CLOSED 2026-08-22)
    - Issue: [#9862](https://github.com/mixxxdj/mixxx/issues/9862) (OPEN)
    - Created: 2025-10-25, Last comment: none, Last review: none, Rebased: 2026-08-20, Updated: 2026-08-22
    - Next: Await review on #16921
    - Specifics:
      - Tracker DSP moved from SoundSource decoder to native built-in effect (`org.mixxx.effects.trackerdsp`) per daschuer architecture feedback
      - OpenMPT decoding is bit-perfect — no optional DSP applied inside `SoundSourceOpenMPT`
      - Former module-FX controls (reverb, mega bass, surround, noise reduction) exposed as editable parameters in effect rows
      - Modplug preferences pane removed in favor of effect-row parameters
      - `SoundSourceOpenMPTTest`: open, seek consistency, read-beyond-end, multiple buffer sizes (6 tests)
      - `TrackerEffectTest`: manifest validation, disabled passthrough, enabled processing with individual and combined DSP effects, state reset (7 tests)
      - Full `mixxx-test` suite passes (1195 tests)
      - Intermittent double-free crash under heavy library scanning — not reproduced in 8 consecutive runs; investigation ongoing
      - Test fix 2026-02-19: `taglibStringToEnumFileType` now excludes all openmpt tracker formats
    - Tested?: no (human test with real module files and DJ setup still required)
  - [x] **feature/2025.10oct.20-hotcues-on-overview-waveform** - [#15514](https://github.com/mixxxdj/mixxx/pull/15514) - DRAFT - REVIEW_REQUIRED
    - **PR head repointed** 2026-08-21: fork branch `feature/hotcues-on-overview-waveform` force-pushed to match the dated ref. The manifest declares `pr_head` so `--push-changed` keeps them in sync going forward.
    - **Branch rewritten** 2026-08-28: minute markers split out into `feature/2026.08aug.28-library-overview-minute-markers`; this branch now contains hotcue rendering only, squashed to 1 commit
    - Issue: [#14994](https://github.com/mixxxdj/mixxx/issues/14994) (OPEN)
    - Created: 2025-10-20, Last comment: 2026-01-19 (stale-bot), Last review: 2025-10-20 (ronso0, COMMENTED), Rebased: 2026-08-28 (rewrite), Updated: 2026-08-28
    - Next: Repoint the PR head to the dated ref, which also rebases it; await review
    - Specifics:
      - Hotcue rendering only (minute markers moved to separate branch)
      - OverviewCache API changed from TrackId to TrackPointer to access cue points and duration
      - Hotcues drawn as contrasting border + bright fill lines, matching deck overview style
    - Tested?: no
  - [x] **feature/2025.11nov.17-deere-channel-mute-buttons** - [#15624](https://github.com/mixxxdj/mixxx/pull/15624) - DRAFT - REVIEW_REQUIRED
    - Issue: [#15623](https://github.com/mixxxdj/mixxx/issues/15623) (OPEN)
    - Created: 2025-11-17, Last comment: 2026-02-23 (ronso0), Last review: none, Rebased: 2026-08-20, Updated: 2026-08-20
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
  - [ ] **feature/2026.08aug.23-deere-hotcue-count-selector** - [#16932](https://github.com/mixxxdj/mixxx/pull/16932) - DRAFT
    - Created: 2026-08-23, Last comment: 2026-08-25 (mxmilkiib), Updated: 2026-08-25
    - Next: Finish testing, mark as ready for review
    - Specifics:
      - Commits: `e4da42d283` LateNight: add 16 hotcues option; `999e389f91` Deere: rework hotcue count selector using WidgetStack
      - ronso0 published related LateNight 16-hotcues mod #16934; adjusted to work like #16934 with #16941
    - Tested?: no
- 🟤 **External PRs (Testing — not our PRs, do not push)**
  - [x] **feature/2026.03mar.09-head-split-reverse** - [#16137](https://github.com/mixxxdj/mixxx/pull/16137) - EXTERNAL
    - Author: yashrajpurohit7 · PR head: `feature/head-split-reverse` (on contributor's fork)
    - Issue: [#14821](https://github.com/mixxxdj/mixxx/issues/14821)
    - Created: 2026-08-25 (local cherry-pick), PR opened: 2026-03-09, Rebased: 2026-08-25, Updated: 2026-08-25
    - Local ref is a cherry-pick of the PR's single commit rebased onto `upstream/main` for integration dogfooding
    - Next: Monitor upstream PR for review feedback or merge; rebuild integration when the PR updates
    - Specifics:
      - Adds `[Master],head_split_reverse` ControlPushButton to invert split cue channels
      - When enabled, swaps left/right in split cue mode — main mix in left ear, headphone mix in right
      - Logic in `processHeadphones()` in `enginemixer.cpp`; TODO in PR: add to preferences panel
    - Tested?: no
  - [x] **feature/2026.05may.31-waveform-zoom-controlpotmeter** - [#12387](https://github.com/mixxxdj/mixxx/pull/12387) - EXTERNAL
    - Author: ronso0 · PR head: `waveform-zoom-controlpotmeter` (on contributor's fork)
    - Created: 2026-08-25 (local cherry-pick), PR opened: 2023-12-02, Rebased: 2026-08-25, Updated: 2026-08-25
    - Local ref is a cherry-pick of the PR's single commit rebased onto `upstream/main` for integration dogfooding
    - Next: Monitor upstream PR for review feedback or merge; rebuild integration when the PR updates
    - Specifics:
      - Converts `waveform_zoom` from ControlObject to ControlPotmeter (adds `_up`, `_down`, `_set_default`)
      - Step size 1 — `_up`/`_down` act exactly as before
      - C++ alternative to #12373; manual updated via mixxxdj/manual#722
      - Touches `dlgprefwaveform.cpp` (merge_order 220, after all local dlgprefwaveform branches) and `Deere/style.qss`
    - Tested?: no
- ⚠️ **Schema-Changing Branches (Excluded from Integration)**
  - [ ] **feature/2025.10oct.17-library-column-hotcue-count** - [#15462](https://github.com/mixxxdj/mixxx/pull/15462) - REVIEW_REQUIRED
    - **PR head repointed** 2026-08-21: fork branch `feature/library-column-hotcue-count` force-pushed to match the dated ref. The manifest declares `pr_head` so `--push-changed` keeps them in sync going forward.
    - Issue: [#15461](https://github.com/mixxxdj/mixxx/issues/15461) (CLOSED 2025-11-16 as DUPLICATE — the driving issue is gone; decide whether the PR still has a home before spending more on it)
    - Created: 2025-10-17, Last comment: 2026-01-17 (stale-bot), Last review: none, Rebased: 2026-08-20 (local ref only), Updated: 2026-08-20
    - Next: Resolve the head mismatch and the closed-issue question before touching the schema work
    - Specifics:
      - PR marked stale (Jan 17 2026) — needs activity to unstale
      - Broad discussion about whether hotcue count column is the right approach vs a "prepared" state flag (daschuer, ronso0)
      - Potential pie chart icon instead of plain number (daschuer suggestion)
      - Related to hotcues-on-overview-waveform PR #15514 (acolombier suggested rendering hotcues in overview column instead)
      - Schema change v39→v40 — will conflict with other schema changes
      - Removed from integration: cross-thread SQLite crash (Qt::DirectConnection cuesUpdated lambda runs updateTrackHotcueCount on engine thread)
      - Crash fixed in branch: cuesUpdated now uses AutoConnection + DB-counting overload; CueDAO::updateTrackHotcueCount(TrackId) made public
    - Tested?: no
  - [ ] **feature/2025.11nov.16-catalogue-number-column** - [#15616](https://github.com/mixxxdj/mixxx/pull/15616) - REVIEW_REQUIRED
    - Issue: [#12583](https://github.com/mixxxdj/mixxx/issues/12583) (OPEN)
    - Created: 2025-11-16, Last comment: none (no issue comments), Last review: 2026-02-15 (mxmilkiib, COMMENTED), Rebased: 2026-08-20, Updated: 2026-08-20
    - Next: Await review
    - Specifics:
      - acolombier left review comment 2026-02-14; replied 2026-02-15
      - Schema migration revision 40 — will conflict with hotcue-count branch (also schema change)
      - Removed from integration: schema change; keeping integration at upstream schema v40 until schema branches are stable
      - Uses MusicBrainz Picard tag mapping conventions
    - Tested?: no
- 🔵 **Local Only (No PR)**
  - [ ] **feature/2026.08aug.23-register-middle-side-button-events** — LOCAL_ONLY
    - Created: 2026-08-23, Updated: 2026-08-23
    - Commit: `d19c2f454d` — Register MiddleButton, BackButton, and ForwardButton events for buttons
    - Next: Test, decide whether to open an upstream PR
  - [ ] **feature/2026.08aug.23-register-middle-wheel-scroll** — LOCAL_ONLY
    - Depends-on: feature/2026.08aug.23-register-middle-side-button-events
    - Created: 2026-08-23, Updated: 2026-08-23
    - Commits: `d19c2f454d` (from side-button-events) + `60f7bab83d` — Register scroll-wheel events for buttons
    - Next: Test, decide whether to open an upstream PR
  - [ ] **latenight-16-hotcues-test** — LOCAL_ONLY
    - Created: 2026-08-24, Updated: 2026-08-24
    - Commit: `95f46f6972` — LateNight: add 16 hotcues option
    - Note: branch ref lacks `feature/` prefix — non-standard name
    - Next: Test, decide whether to open an upstream PR or fold into deere-hotcue-count-selector
  - [ ] **draft/2025.10oct.21-tracker-module-stems** — ARCHIVED
    - Created: 2025-10-21, Rebased: 2026-08-03, Updated: 2026-08-10, Archived: 2026-08-10
    - Test binary: [build-fail 2026-05-13]
    - Next: Archived — `openmpt::module::set_channel_mute_status` is absent from the stable C++ API (verified against libopenmpt 0.8.6); no alternative mute/channel-render method found. Depends on replace-libmodplug-with-libopenmpt (#15519) being accepted first. Worktree removed.
  - [ ] **bugfix/2026.02feb.19-wglwidget-xcb-resize-gap** — ABANDONED
    - Created: 2026-02-19, Updated: 2026-02-19
    - Next: Archive or delete branch
    - Specifics:
      - Attempted WA_PaintOnScreen on WGLWidget to reduce XCB resize gap
      - Abandoned: WGLWidget lacks paintEngine(), WA_PaintOnScreen causes heap corruption abort
      - Gap is inherent to QOpenGLWindow+createWindowContainer; no viable fix
- 🟣 **Personal Only (No PR, deliberately not for upstream)**
  - [x] **feature/2025.10oct.08-utf8-string-controls** — PERSONAL_ONLY
    - Dependency for: hotcue-labelling, hotcue-label-options
    - Created: 2025-10-08, Rebased: 2026-08-20, Updated: 2026-08-20
    - Next: Maintain for personal use (not for upstream)
  - [x] **feature/2025.09sep.25-hotcue-labelling** — PERSONAL_ONLY
    - Created: 2025-09-25, Rebased: 2026-08-20, Updated: 2026-08-20
    - Next: Maintain for personal use
  - [x] **feature/2025.10oct.14-waveform-hotcue-label-options** — PERSONAL_ONLY
    - Created: 2025-10-14, Rebased: 2026-08-20, Updated: 2026-08-20
    - Next: Maintain for personal use
- ✅ **Merged to Upstream**
  - [x] ~~**bugfix/2026.02feb.20-fix-learning-wizard-from-prefs-button**~~ - [#16018](https://github.com/mixxxdj/mixxx/pull/16018) **CLOSED** 2026-02-28 — fix folded into #15577 (commit ffc28f8); bug only manifested in context of wizard menu changes; not a standalone upstream issue
  - [x] ~~**bugfix/2026.02feb.18-midi-makeinputhandler-null-engine**~~ - [#16003](https://github.com/mixxxdj/mixxx/pull/16003) **MERGED** 2026-06-18 — daschuer APPROVED; merged upstream (PR base 2.5); worktree removed 2026-06-18
  - [x] ~~**feature/2025.06jun.08-deere-deck-bg-colour**~~ **MERGED** — commit `cca2285b36` in upstream/main (change deck bg to subtle shade of deck colour, landed with Deere stems work); worktree removed 2026-05-11
  - [x] ~~**feature/2025.05may.14-fivefourths**~~ - [#16026](https://github.com/mixxxdj/mixxx/pull/16026) **MERGED** 2026-03-11 — merged upstream as Swarnadip-Kar's PR with fourfifths + BPM lock
  - [x] ~~**bugfix/2026.02feb.20-controlpickermenu-quickfx-deck-offset**~~ - [#16019](https://github.com/mixxxdj/mixxx/pull/16019) **MERGED** 2026-03-11 — ronso0's fix merged to main
  - [x] ~~**bugfix/qt6-guiprivate-missing-component**~~ **RESOLVED** 2026-02-19 — fixed upstream, branch deleted
  - [x] ~~**feature/2025.11nov.05-waveform-cache-size-format**~~ - [#15578](https://github.com/mixxxdj/mixxx/pull/15578) **MERGED** 2026-02-16
  - [x] ~~**bugfix/2025.11nov.04-reloop-shift-jog-seek**~~ - [#15575](https://github.com/mixxxdj/mixxx/pull/15575) **MERGED** 2026-02-15
  - [x] ~~**bugfix/2025.11nov.16-reloop-beatmix-mk2-naming**~~ - [#15615](https://github.com/mixxxdj/mixxx/pull/15615) **MERGED** 2026-02-11
  - [x] ~~**bugfix/2025.11nov.04-fx-routing-persistence**~~ - [#15574](https://github.com/mixxxdj/mixxx/pull/15574) **MERGED** 2025-11-14

---

## TODO Summary

This section is only the short list of things that are actively wrong or actively waiting on Milkii.
Detailed per-branch status lives in the outline above and is not repeated here, aside from the branch name and a brief description of the state.

- **Blocking, system-level**
  - The exact-SHA transactional pipeline changes dated 2026-08-21 are working-tree changes only. A human MUST review and commit them, sync the Gist, place them on `integrating` and default-branch `integrated`, then observe one complete CI promotion and package run before declaring the remote automation active.
  - ~~4 PRs point at legacy undated fork branches~~ RESOLVED 2026-08-21: all 4 PR heads (#15516, #15519, #15514, #15462) force-pushed to match their dated refs. #15519 closed 2026-08-22 and superseded by #16921 (dated ref, no `pr_head` needed). The remaining 3 manifest entries declare `pr` and `pr_head` so `--push-changed` keeps them in sync.
- **Waiting on reviewers** — 7 changes-addressed PRs; nothing to do but re-request review on the stale ones
- **Waiting on Milkii**
  - #16021 simple-waveform — daschuer's upgrade path issue is the only unaddressed change request
  - #15519 libopenmpt — CLOSED 2026-08-22, superseded by #16921 (tracker DSP moved to effect rack, tests added)
  - extend-waveform-zoom-range and fix-timer-test-potmeter-clamping have no PR at all
  - #15624 deere-channel-mute-buttons is on hold pending a broader plan, not pending code
- **CI status** — PASS. Run #33120201431 for SHA `777d21f25b043ae8653c84a119bc67c97141c7d3` completed with all jobs green (coverage, clazy, clang-tidy, all builds). `integrated` force-updated to this SHA (non-fast-forward because main moved between candidates). Includes uniform time base (#16925), invert zoom (#16928), deere hotcue count (#16932), and the OpenMPT duplicate MIME type fix.
- **Architecture changes needed:** none outstanding — replace-libmodplug-with-libopenmpt tracker DSP effect rack refactor done, PR #16921 open for review
- **Archived:** tracker-module-stems (libopenmpt API gap, worktree removed 2026-08-10)
- **Secondary patches:** hid-init-race-on-enumeration (#16838 — REVIEW_REQUIRED, opened 2026-08-04), fix-timer-test-potmeter-clamping (no PR yet)
