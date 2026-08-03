prompt: Mixxx personal integration system — worktree-per-branch development, automated rebase/build/test, three-tier promotion chain, CI-conscious push policy

# Mixxx Integration Branch Configuration

> Last updated: 2026-08-03 21:55 (session 11)
> URL: https://gist.github.com/mxmilkiib/5fb35c401736efed47ad7d78268c80b6
> [RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119)

One git database, many worktrees. Each feature or bugfix lives in its own worktree under `~/src/mixxx-dev/`, branched from upstream main. A script rebases all branches, builds test binaries, and runs the test suite. Branches that pass are merged into an `integration` branch and promoted through three gates: `integration` (working scratchpad) → `integrating` (locally tested) → `integrated` (CI confirmed). Pushes to open PR branches happen only when the patch content has actually changed — pure rebases are never pushed, to avoid wasting shared CI resources.

## Session Start Protocol

Run these checks automatically at the start of every session, before any other work:

1. **Promotion check** — run: `gh run list --branch integrating --repo mxmilkiib/mixxx --limit 1 --json status,conclusion,headSha`. If `"conclusion": "success"` and the SHA differs from `$(git -C ~/src/mixxx-dev/integration rev-parse integrated)`, run `--promote-integrated` immediately.
2. **URGENT scan** — check the Branch Status Outline for any entries marked `URGENT` and report them.
3. **Stale sentinel check** — for any branch whose sentinel SHA (`~/.cache/mixxx-integration/<name>.tested`) does not match its current `git rev-parse HEAD`, note it as needing a re-test before the next `--push-integrating`.

## Rules

- **Purpose**: This living document tracks Milkii's personal Mixxx development setup, for creating and testing feature and bugfix branches, and MUST be updated as the workflow evolves.
- **Last updated**: The "Last updated" date at the top of this file MUST be updated whenever this file is edited
- **Gist sync**: This file AND `mixxx-integration-update-branches.sh` MUST be kept in sync with the Gist (https://gist.github.com/mxmilkiib/5fb35c401736efed47ad7d78268c80b6).
    - To sync INTEGRATION.md: `gh gist edit 5fb35c401736efed47ad7d78268c80b6 --filename INTEGRATION.md INTEGRATION.md`.
    - To sync the script: `gh gist edit 5fb35c401736efed47ad7d78268c80b6 --filename mixxx-integration-update-branches.sh mixxx-integration-update-branches.sh`.
    - Both files MUST be updated whenever they change.
- **Dual dir**: All source trees share the SAME `.git` database rooted at `~/src/mixxx/.git`. Registered worktrees are not separate clones — `git log`, `git branch -a`, etc. show all branches from any path.
  - `~/src/mixxx/` — checked out on `integrated`; `build/mixxx` here is the CI-confirmed daily-driver binary
  - `~/src/mixxx-dev/integration/` — checked out on `integration`; script and helper files live here; this is where `./mixxx-integration-update-branches.sh` is run from
  - `~/src/mixxx-dev/<branch>/` — individual feature/bugfix worktrees
- **Main sync**: The project repo MUST maintain a `main` branch that is synced with `mixxxdj/mixxx` main. `origin/main` MUST be kept as a fast-forward mirror of `upstream/main` — run `git push --no-verify origin main` after every `git fetch upstream && git merge upstream/main` on `main`.
- **Main read-only**: The `main` branch MUST NOT receive any local commits — not INTEGRATION.md updates, not patches, nothing. All commits go on `integration` or a worktree branch. Any stray commits on `main` MUST be removed by force-pushing the clean `upstream/main` tip.
- **Worktrees**: All development MUST use worktrees, keeping individual branches clean for upstream PRs. The `integration` worktree at `~/src/mixxx-dev/integration/` is the script's operating base; `~/src/mixxx/` MUST remain on `integrated` so its `build/mixxx` is always the CI-confirmed binary.
- **Branch tiers**: The `mixxx` repo MUST maintain three promotion-chain branches:
  - `integration` — working merge branch; script operates here; may be broken at any time. Rebuilt from scratch on each run by merging `upstream/main` then all `[x]`-marked worktree branches in order — it is intentionally ephemeral and MUST NOT be treated as stable.
  - `integrating` — locally-tested-clean tier; promoted from `integration` only after ALL non-skipped worktrees have passing test suites (`--push-integrating`); triggers GA CI. Local tests run against the same kernel/libraries/ccache as the build; they catch logic regressions but not environment or flag differences.
  - `integrated` — CI-confirmed-clean tier; promoted from `integrating` only after GA CI passes on `origin/integrating` (`--promote-integrated`); safe to build from daily. GA CI runs a full build + unit test suite on a clean runner with no shared cache, catching missing-dependency or build-flag issues invisible to local tests.
  Three tiers exist because local-passing does not imply clean-environment-passing: a missing system header, a flag difference, or a locally-installed library can mask a real breakage. `integrating` is the staging gate; `integrated` is the confirmed-clean consumption tier.
  `integration` combines all `[x]`-marked branches from `mixxx-dev` worktrees.
- **Dev location**: All individual branch development should be done using the `mixxx-dev` worktree directory
- **Integration edits**: `mixxx` can have some edits for testing purposes, but should be kept minimal
- **Clean commits**: A branch in `mixxx-dev` MUST have clean commits before first being linked with a GitHub PR
- **Stability**: This dual setup SHOULD provide consistency for a stable bleeding-edge build without interference from local development.
- **"Updating" the system**: When the user asks to "update" or says the system has been updated, this MUST include all of the following post-update checks and tasks in order:
  1. Fetch `upstream` and check for new commits on `upstream/main`
  2. Check all `[x]` branches: for each, verify whether its commits are already present in `upstream/main` (`git log upstream/main --oneline | grep <keyword>`); if fully merged, move the entry to the "Merged to Upstream" section, remove the `[x]` marker, and record the merge date — do this BEFORE rebasing or rebuilding so merged branches are excluded from both
  3. Rebase all non-merged worktree branches on new `upstream/main` (stash any WIP first); skip branches identified as merged in step 2; clean any branches with INTEGRATION.md or other cruft commits. **Rebasing does NOT push** — use `--push-changed` explicitly when PR branches need updating (e.g. after addressing review feedback, or to clear stale-bot)
  4. Rebuild the `integration` branch: merge `upstream/main` then re-merge all `[x]` branches in order, resolving any conflicts
  5. Build the integration branch (`cmake --build build --target mixxx -- -j$(nproc --ignore=2)`) and verify it succeeds
  6. All local tests must pass across ALL non-skipped worktrees. Run `--build-all-tests` to configure cmake and build any missing binaries (also rebuilds stale ones), then `--run-tests` to confirm 0 failures. Both steps are done automatically by `--full`. Once clean, run `--push-integrating` to promote `integration` → `origin/integrating`. This triggers GA CI.
  6b. Wait for GA CI on `origin/integrating`: `gh run list --branch integrating --repo mxmilkiib/mixxx`. Once all checks pass, run `--promote-integrated` to fast-forward `integrated` → `origin/integrated`. If CI fails, investigate whether failures are pre-existing on `upstream/main` or integration-introduced; do not promote until confirmed pre-existing or fixed.
  7. Check all open PRs for new review feedback (CHANGES_REQUESTED, new comments) and update INTEGRATION.md statuses accordingly
  7b. If any PR branches have actual content changes (review feedback addressed, conflict resolutions), run `--push-changed` to push only those branches whose patch differs from origin — pure rebases are skipped to conserve upstream CI resources
  8. Update the "Last updated" timestamp and rebuild log entry in INTEGRATION.md, commit, and sync to Gist
- **Merge process**: The integration merge process MUST follow the steps in the **Integration Merge Process** section below.
- **Rebase hygiene**: All branches SHOULD be kept up-to-date and rebased with `mixxxdj/mixxx` main to minimize merge conflicts, except merged branches
- **Rebase first**: A branch MUST be rebased as an initial step before any new change is made to said branch
- **Incremental PRs**: Changes to `mixxxdj/mixxx` PRs MUST be incremental so as to be easy to review, and MUST NOT completely reformulate a system in a single commit.
- **Outline currency**: The integration status outline MUST reflect the state of all branches, related issues, PRs, and dates, and MUST be updated after changes are committed — PR URLs SHOULD be checked first to catch new feedback
- **Non-interactive git**: Git operations MUST be non-interactive using `GIT_EDITOR=true` and `GIT_PAGER=cat` to avoid vim/editor prompts
- **Issues**: Most branches MAY have related upstream issues; related issues SHOULD be listed in the outline
- **Sections**: Feature and fix branches should be in the correct outline sections
- **Secondary patches**: Secondary patches are small fixes that either (a) resolve a residual problem that only became visible after a larger fix landed, or (b) are a prerequisite that a main fix branch depends on. They MUST be tracked in the **Secondary Patches** section of the outline, with a `Depends-on` or `Resolves-residual-from` note linking them to the related primary branch
- **Secondary patch upstream**: A secondary patch SHOULD be submitted upstream independently if it stands alone; if it only makes sense in context of the primary fix, it MAY be folded into that PR
- **Dates**: Dates for branch creation, last PR comment, and last update MUST be recorded in the status outline
- **Standalone branches**: Each feature/fix branch SHOULD work standalone without depending on other local branches (except where noted)
- **History**: Feature/fix branch history MUST NOT be rewritten (no squash, no interactive rebase) without explicit permission from Milkii. "Complete" means the upstream PR has been merged or the branch has been deliberately closed. The integration branch MAY have merge commits.
- **No cherry-pick**: ALWAYS use `git merge` to bring branches into integration, NEVER `git cherry-pick` — cherry-picking creates duplicate commits with different SHAs, severs the branch relationship, makes bisect/revert unreliable, and hides what is actually in the build from `git log`
- **Dependencies**: Any fix or feature branch that relies on another local branch MUST be noted in the Branch Dependencies section
- **Local-only**: Some features (UTF-8 string controls) MUST NOT be submitted to `mixxxdj/mixxx` upstream as they are local-only/personal use
- **PR flow**: PRs SHOULD be submitted to `mxmilkiib/mixxx`, and Milkii will create a further PR from there to `mixxxdj/mixxx`.
- **Merged cleanup**: Once the PR is fully merged into `mixxxdj/mixxx`, the branch entry MUST be moved to the "Merged to Upstream" section of the outline and its `[x]` marker removed, so it is excluded from future integration rebuilds.
- **Upstream-resolved cleanup**: If an upstream commit (by any contributor) fully resolves the problem a local branch was addressing — rendering the local branch redundant or superseded — the branch entry MUST also be moved to the "Merged to Upstream" section and marked **RESOLVED** (not MERGED), with a note identifying the upstream commit or PR that resolved it. The worktree MUST then be pruned per the **Worktree pruning** rule.
- **Upstream verification before closing**: Before closing or marking a PR/branch as RESOLVED, the fix MUST be verified by reading the actual code in `upstream/main` and `upstream/2.5` — `git show upstream/main:path/to/file.cpp | grep -A N "function"`. A verbal claim that the fix is upstream is NOT sufficient. If verification fails, do not close the PR.
- **Commit messages**: Commit messages must not be too verbose, and should be concise and descriptive.
- **Conflict resolution**: When resolving merge conflicts — whether during rebases or integration merges — conflicts MUST be resolved and the operation continued non-interactively
- **Code quality**: Code quality MUST be verified before pushing — code should be proper, straight to the point, robust, and follow Mixxx coding style
- **Push permission**: Permission MUST be sought from the user before pushing commits to GitHub. Once the user has confirmed a push in a session, further pushes in that same session MAY proceed without asking again, to reduce friction.
- **Worktree pruning**: When a branch is merged upstream, closed, or abandoned, its worktree MUST be removed (`git worktree remove ~/src/mixxx-dev/<name>`) and the local branch ref MAY be deleted. This keeps `mixxx-dev/` lean and prevents `mixxx-integration-update-branches.sh` from wasting time on dead branches.
- **Schema exclusion**: Branches that introduce database schema migrations MUST NOT be merged into the integration branch unless all schema-changing branches use compatible, non-conflicting revision numbers. Schema branches are tracked in a dedicated "Schema-Changing Branches" section of the outline.
- **Local-only backup**: All local-only branches MUST be pushed to `origin` (`mxmilkiib/mixxx`) for off-machine backup, even if they will never be PRed upstream. All worktrees share a single `.git` directory — losing it means losing every unpushed branch.
- **LOCAL_ONLY dependency chains**: When rebasing branches that form a LOCAL_ONLY dependency chain, the dependency root MUST be rebased first, then each dependent in topological order. If the root bitrots or conflicts, all dependents are broken until the root is fixed.
- **mixxx-integration-update-branches.sh**: The script MUST exist as a committed file in the `integration` branch and MUST be run from `~/src/mixxx-dev/integration/`. All `${MIXXX_DEV}/*/` loops in the script MUST guard with `[[ "$name" =~ ^[0-9]{4}\. ]] || continue` so promotion-chain worktrees (`integration`, `integrating`, `integrated`) — which lack the `YYYY.` date prefix — are never treated as feature branches. It MUST skip worktrees whose branches have been merged upstream, closed, or abandoned.
- **Test binary staleness**: After any system library upgrade (e.g. protobuf, Qt, libstdc++), the `build/mixxx-test` binary in each worktree MUST be rebuilt before pushing — stale binaries will fail the pre-push hook with a dynamic linker error, not a test failure. Run `ldd <worktree>/build/mixxx-test | grep 'not found'` to detect staleness without rebuilding. Use `mixxx-integration-update-branches.sh --rebuild-tests` to rebuild all stale test binaries serially.
- **Single-branch build**: When the user asks to build a specific branch or worktree, ALWAYS build the full `mixxx` executable (`cmake --build <worktree>/build --target mixxx`), NOT just `mixxx-test`. The test binary is built separately by the integration script; a user-requested build means they want a runnable binary. Build command: `CCACHE_BASEDIR=~/src/mixxx-dev/<name> nice -n 15 cmake --build ~/src/mixxx-dev/<name>/build --target mixxx -j$(nproc)`.
- **Build type**: All worktree builds MUST use `CMAKE_BUILD_TYPE=RelWithDebInfo`. Debug builds abort on `DEBUG_ASSERT` calls, causing tests to crash with non-zero exit that looks like a test failure (e.g. `SoundSourceProxyTest.openEmptyFile` firing `FileInfo::canonicalLocation` assert). Release builds suppress the crash but lose debug symbols. `RelWithDebInfo` is the correct balance. Check: `grep CMAKE_BUILD_TYPE <worktree>/build/CMakeCache.txt`. Reconfigure with: `cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo <worktree>/build`.
- **Test serialisation**: Local tests MUST be run serially (`run_tests_serial`), not in parallel. Multiple concurrent `mixxx-test` processes share the same audio device mocks, ControlObject registry, and SQLite test databases — parallel runs cause non-deterministic failures and resource exhaustion. Serial execution ensures reproducible results. Build compilation IS parallel within each worktree (`-j$(nproc --ignore=2)`) and configure steps are parallelised across worktrees.
- **Build parallelism**: NEVER launch multiple full worktree builds simultaneously — 5 × `-j$(nproc)` on a 32-core machine means 150 competing jobs and effectively no progress. Worktree builds MUST be run serially using `-j$(nproc --ignore=2)`. With ccache + CCACHE_BASEDIR correctly set, each subsequent build is mostly cache hits making serial runs fast.
- **Killing builds**: `pkill -f cmake` only kills the cmake wrapper — ninja/make/cc1plus children survive and saturate the CPU. To kill a full build tree: `ps aux | grep -E 'cc1plus|ninja|/usr/bin/make' | grep -v grep | awk '{print $2}' | xargs -r kill -9`. In the script, Ctrl-C triggers a `kill 0` trap that kills the whole process group cleanly.
- **ccache**: All worktree builds MUST be configured with `-DCCACHE_SUPPORT=ON`. Cache size SHOULD be 15 GB or more. To enable on an existing build: `cmake -DCCACHE_SUPPORT=ON <worktree>/build` (in-place reconfigure).
  - **Cross-worktree sharing requires `CCACHE_BASEDIR`**: worktrees are at different paths, so preprocessor `#line` markers embed different absolute paths in the hash. Setting `CCACHE_BASEDIR=<worktree-root>` at build time strips that prefix, making paths relative — identical upstream files then produce the same hash across worktrees. This is set automatically by `mixxx-integration-update-branches.sh`; manual builds MUST also set it: `CCACHE_BASEDIR=~/src/mixxx-dev/<name> cmake --build ...`.
  - `hash_dir = false` in `~/.config/ccache/ccache.conf` prevents the build directory path from entering the hash (complementary to CCACHE_BASEDIR). Both settings are needed for robust cross-worktree sharing.
- **Skip list vs integration markers**: `SKIP_BRANCHES` in `mixxx-integration-update-branches.sh` covers only branches whose worktrees are removed, merged, or abandoned — these are skipped in ALL operations. LOCAL_ONLY and schema-excluded branches are NOT in SKIP_BRANCHES; they are still rebased and tested. They are excluded only from integration merges, tracked via `[ ]` vs `[x]` markers in the Branch Status Outline (manual step).
- **Upstream test filter scope**: When filtering known-failing upstream tests, filter the ENTIRE affected test suite (e.g. `ControllerScriptEngineLegacyTimerTest.*`) not just the specific failing cases. Individual tests in the suite that nominally pass can still corrupt shared QTimer/ControlObject state, causing unrelated downstream tests (e.g. `MidiMappings/MappingTestFixture`) to hang indefinitely. Root cause: `coTimerId ControlPotmeter max=50` clamps any QTimer ID > 50, producing collisions that prevent timer callbacks from firing. Filtering the entire suite prevents state poisoning. Remove when upstream fix lands.
- **Pre-push hook timeout**: The hook runs `timeout 420 ./mixxx-test` to prevent indefinite hangs. If the timeout fires, it reports the last test name and blocks the push. Investigate the hanging test by running it in isolation first (`./mixxx-test --gtest_filter=SuiteName`) — if it passes alone, it is a state-poisoning issue from a preceding test.
- **Monitoring progress**: `mixxx-integration-update-branches.sh --full` writes timestamped phase/branch updates to `STATUS_FILE=/tmp/mixxx-integration-status`. In a second terminal: `tail -f /tmp/mixxx-integration-status`. Individual test suite logs: `tail -f /tmp/mixxx-test-logs/<worktree>.log`. During test runs, a heartbeat prints test count every 30 s to the main terminal so it never appears frozen.
- **File edits**: All file changes to tracked files MUST be made with the IDE's `edit`/`write_to_file` tools (showing diffs in the editor), NEVER via shell commands (`echo >`, `tee`, `sed -i`, etc.) which bypass the diff view entirely.
- **Promotion currency**: `integrated` MUST NOT lag behind a passing `integrating`. At the start of any session — before any other work — check whether `origin/integrating` has a completed, passing CI run that has not yet been promoted: `gh run list --branch integrating --repo mxmilkiib/mixxx --limit 1 --json status,conclusion,headSha`. If it shows `"conclusion": "success"` and the SHA differs from the current `integrated` HEAD, run `--promote-integrated` immediately. Letting `integrated` sit stale means `~/src/mixxx/build/mixxx` is not the CI-confirmed binary.
- **Branch tier semantics**: `integration` ≠ `integrating` ≠ `integrated`. These are three distinct promotion gates, not aliases:
  - `integration` is a working scratchpad — never guaranteed to build or pass tests.
  - `integrating` is locally-tested-clean — every non-skipped worktree passed its test suite with 0 failures. This is NOT CI-confirmed.
  - `integrated` is CI-confirmed-clean — GA confirmed `origin/integrating` passed all platform checks. This is the branch to build from.
  `integrated` ≠ "guaranteed to build everywhere" — CI may still filter some known-upstream failures via `KNOWN_FAILING`. Its guarantee is: locally clean + GA Linux/macOS/Windows builds passed.
- **Test binary completeness**: Before `--push-integrating` can succeed, ALL non-skipped worktree branches MUST have a `build/mixxx-test` binary AND each must have a per-branch passing sentinel for its current HEAD. `--full` uses `--build-all-tests` which: (1) launches all cmake configures **in parallel** (configure is I/O-bound; 16 configures take ~5s instead of ~70s serial), then (2) builds `mixxx-test` serially with `-j(nproc-2)`, then (3) prints a `ccache -s` summary. Standalone: `--build-all-tests` then `--run-tests`. The script lists all blocking branches when `--push-integrating` is blocked. `--rebuild-tests` still exists but only handles stale binaries (ldd-detected) — it does NOT configure unconfigured branches.
- **Per-branch test status**: Each active branch entry in this document SHOULD carry a `Test binary:` field with one of: `[no-build]`, `[build-only]`, `[test-pass YYYY-MM-DD]`, `[test-fail YYYY-MM-DD]`. This is updated manually after each `--run-tests` run. The field reflects the LAST KNOWN state; the script is authoritative for the current live state.
- **CI-conscious pushing**: Feature branch force-pushes to `origin` trigger full CI matrix on `mixxxdj/mixxx`. A pure rebase (same patch, different base) has zero CI value — it wastes shared runner time and annoys reviewers who monitor PR activity. `rebase_all()` no longer pushes; use `--push-changed` to push only branches whose `git diff upstream/main..HEAD` differs from `git diff upstream/main..origin/<branch>`. Manual pushes (e.g. after addressing review feedback) bypass this — push directly from the worktree as needed.
- **Per-branch test sentinel**: After each test run, `run_tests_serial` writes `~/.cache/mixxx-integration/<name>.tested` containing `<branch-HEAD-SHA> pass|fail`. Sentinels survive reboots (unlike `/tmp/`). `run_tests_serial` is **selective**: branches whose sentinel matches their current HEAD SHA and status is `pass` are skipped, so re-runs after a single branch rebase only re-test that branch (~3 min vs ~65 min). `push_integrating` Gate 2 checks each branch's sentinel individually — reports exactly which branches need attention. A global summary sentinel is also written to `~/.cache/mixxx-integration/tests-passed` for auditing. Invalidation is automatic: when a branch rebases its HEAD SHA changes, making the sentinel stale.


## Worktree Branch Hygiene

**CRITICAL**: `mixxx-dev/` worktrees MUST only contain commits belonging to their named feature.

- NEVER commit INTEGRATION.md, integration merge commits, or unrelated fixups into a fix or feature worktree
- INTEGRATION.md MUST NOT be committed to any feature branch in `mixxx-dev/`
- Before making any edit in `mixxx-dev/`, confirm the active worktree matches the intended branch:
  ```bash
  git -C ~/src/mixxx-dev/<worktree>/ branch --show-current
  ```
- To verify a worktree is clean (only its own commits ahead of upstream/main):
  ```bash
  git -C ~/src/mixxx-dev/<worktree>/ log --oneline upstream/main..HEAD
  ```
- If a worktree has accumulated cruft, reset it:
  - No real feature commits yet: `git reset --hard upstream/main`
  - Has real commits mixed with cruft: rebase only the feature commits onto upstream/main, then force-update the branch ref

### Preventing Cross-Branch Contamination

- **ALWAYS create new feature branches from `upstream/main`, never from local `main`** — defence-in-depth: if `main` ever accumulates stray commits (violating Main read-only), branching from `upstream/main` guarantees a clean base:
  ```bash
  git fetch upstream
  git worktree add ~/src/mixxx-dev/<name> -b feature/<branch-name> upstream/main
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

## Directory Structure

| Path               | Purpose                                                                    |
|--------------------|----------------------------------------------------------------------------|
| `~/src/mixxx/`     | Worktree checked out on `integrated` — CI-confirmed daily-driver binary    |
| `~/src/mixxx-dev/` | Worktrees: `integration/` (script base) + individual feature/fix branches  |

**Branch promotion chain** (all branches live in the single shared `.git` at `~/src/mixxx/`):

```
integration  →[all worktrees pass --run-tests]→  integrating  →[GA CI green]→  integrated
(working, may break)          (locally clean)                  (CI-confirmed)
```

### Branch Dependencies

```
utf8-string-controls (LOCAL_ONLY)
├── hotcue-labelling (LOCAL_ONLY)
└── hotcue-label-options (LOCAL_ONLY)
```

Branches with dependencies on local-only branches cannot be submitted upstream as-is. They MUST be refactored to remove the dependency or the dependency MUST be upstreamed first.

## Branch and Integration Status Outline

**Summary**: 7 CHANGES_REQUESTED, 8 REVIEW_REQUIRED, 2 schema-excluded, 10 merged/resolved upstream, 6 local-only, 2 secondary patches, 2 build-broken/skipped

- 🔴 **Awaiting Review from Others**
  - [x] **feature/2025.11nov.04-controller-wizard-quick-access** - [#15577](https://github.com/mixxxdj/mixxx/pull/15577) - CHANGES_REQUESTED
    - Issue: [#12262](https://github.com/mixxxdj/mixxx/issues/12262)
    - Created: 2025-11-04, Last comment: 2026-02-18, Rebased: 2026-08-03, Updated: 2026-02-22
    - Note: rebased with wmainmenubar.cpp/h conflict resolved (Controller+KeyboardEventFilter both included)
    - Next: Awaiting re-review — ronso0 CHANGES_REQUESTED (Nov 16) addressed Feb 18; fix-learning-wizard folded in Feb 22 (ffc28f8)
    - Specifics:
      - ~~devicesChanged not updating menu post-startup~~ fixed — connected to mappingApplied
      - ~~range-for style on m_controllerPages~~ done
      - fix-learning-wizard folded in: emit mappingStarted() before show() so prefs dialog hides before wizard appears
    - Tested?: yes
  - [x] **feature/2025.10oct.21-stacked-overview-waveform** - [#15516](https://github.com/mixxxdj/mixxx/pull/15516) - DRAFT - CHANGES_REQUESTED
    - Issue: [#13265](https://github.com/mixxxdj/mixxx/issues/13265)
    - Created: 2025-10-21, Last comment: 2026-02-22 (mxmilkiib), Rebased: 2026-08-03, Updated: 2026-02-18
    - Next: Stale bot fired (Feb 22); our naming comment (Feb 17) + clarification (Feb 22) are latest — re-request review to unstale; no new reviewer feedback
    - Specifics:
      - ~~Remove redundant Stacked HSV and Stacked LMH renderers~~ done
      - ~~Remove unnecessary static_cast<int>~~ done
      - ~~Rename "Stacked (RGB)" to "Stacked"~~ done
      - All feedback addressed
      - Left comment 2026-02-17 re: Filtered/Stacked naming confusion — see #15996
    - Tested?: yes
  - [x] **feature/2025.10oct.20-restore-last-library-selection** - [#15460](https://github.com/mixxxdj/mixxx/pull/15460) - DRAFT - CHANGES_REQUESTED
    - Issue: [#10125](https://github.com/mixxxdj/mixxx/issues/10125)
    - Created: 2025-10-08, Last comment: 2026-02-26 (ronso0), Rebased: 2026-08-03, Updated: 2026-02-28
    - Next: CI failing (ronso0 Feb 26) + unrelated Reloop JS changes slipped in — fixed 2026-02-28: removed JS file from commit, cleaned commit message (had # Conflicts: lines), fixed all clang-format violations; re-request review
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
  - [x] **feature/2025.11nov.05-hide-unenabled-controllers** - [#15580](https://github.com/mixxxdj/mixxx/pull/15580) - REVIEW_REQUIRED
    - Issue: [#14275](https://github.com/mixxxdj/mixxx/issues/14275)
    - Created: 2025-11-05, Last comment: 2025-11-17 (ronso0), Rebased: 2026-08-03, Updated: 2026-02-28
    - Next: Awaiting re-review — ronso0 Nov 17 feedback addressed Feb 28: removed redundant null checks, confirmed rename already done
    - Specifics:
      - ~~Rename "unenabled" to "disabled" everywhere — config keys, function names, and UI text (ronso0)~~ done
      - ~~Remove unnecessary null checks on tree items — always valid post-construction (ronso0)~~ done
    - Tested?: yes
- 🔧 **Secondary Patches**
  - [x] **bugfix/2026.05may.01-fix-timer-test-potmeter-clamping** — upstream test bug
    - Created: 2026-05-01, Rebased: 2026-08-03
    - coTimerId ControlPotmeter max=50 clamped QTimer IDs (10000+ in full suite); replaced with ControlObject
    - Next: open upstream PR to mixxxdj/mixxx
    - Workaround: pre-push hook and script filter `ControllerScriptEngineLegacyTimerTest.*` (entire suite — `beginTimer_repeatedTimer` corrupts clamped-ID-50 state, causing `MidiMappings` JS tests to hang; filtering only `singleShot*` is insufficient) and `TrackMetadataExportTest.keepWithespaceKey` (`getKeyText()` returns `B_FLAT_MINOR` internal string instead of `B♭m` display format, fails in all worktrees). Remove filters once upstream fix lands.
  - [x] **bugfix/2026.02feb.21-hid-init-race-on-enumeration** — LOCAL_ONLY
    - Created: 2026-02-21, Rebased: 2026-08-03, Updated: 2026-02-21
    - Note: originally tracked as residual from midi-makeinputhandler (#16003, merged upstream 2026-06-18) — stands alone
    - Next: Evaluate for upstream PR as standalone fix
    - Specifics:
      - `hid_open()` calls `hid_init()` lazily; multiple `HidController` background threads (one per device) race to call it concurrently on startup
      - `hid_init()` on the hidraw backend is not thread-safe — concurrent calls corrupt the udev context, crashing inside `hid_enumerate`
      - Fix: call `hid_init()` explicitly on the main thread in `HidEnumerator::queryDevices()` before `hid_enumerate()` and before any `HidController` objects are constructed
      - Triggered by 3+ HID devices (Launchpad Pro MK3, MPD218, BeatMix4) spawning concurrent background descriptor-fetch threads
    - Tested?: yes (crash no longer reproduced)
- 🐛 **BUG FIXES - Open PRs (REVIEW_REQUIRED)**
  - [x] **bugfix/2026.02feb.19-textured-waveform-fbo-resize** - [#16010](https://github.com/mixxxdj/mixxx/pull/16010) - REVIEW_REQUIRED
    - Created: 2026-02-19, Last comment: none, Rebased: 2026-08-03, Updated: 2026-02-19
    - Next: Await review
    - Specifics:
      - Improved: defer FBO reallocation to paintGL via m_pendingResize flag
    - Tested?: yes
  - [x] **bugfix/2026.02feb.19-openglwindow-resize-repaint** - [#16012](https://github.com/mixxxdj/mixxx/pull/16012) - DRAFT - REVIEW_REQUIRED
    - Created: 2026-02-19, Last comment: none, Rebased: 2026-08-03, Updated: 2026-02-19
    - Next: Await review
    - Specifics:
      - Restores m_dirty flag: defers extra paintGL+swapBuffers from resizeGL to next vsync
      - Does not fix Wayland resize lag (compositor-level issue)
    - Tested?: yes
  - [ ] **bugfix/2026.02feb.19-wayland-opengl-resize-warning** - [#16014](https://github.com/mixxxdj/mixxx/pull/16014) - REVIEW_REQUIRED
    - Issue: [#16013](https://github.com/mixxxdj/mixxx/issues/16013), related [#13814](https://github.com/mixxxdj/mixxx/issues/13814)
    - Created: 2026-02-19, Last comment: 2026-08-03 (daschuer), Rebased: 2026-08-03, Updated: 2026-08-03
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
- 🟡 **NEW FEATURES - Open PRs (REVIEW_REQUIRED)**
  - [x] **feature/2026.05may.03-extend-waveform-zoom-range** — No PR yet
    - Created: 2026-05-03, Rebased: 2026-08-03, Updated: 2026-05-03
    - Next: Test, then open upstream PR
    - Specifics:
      - Extends `s_waveformMinZoom` from 1.0 → 0.5 (allows 200% zoom-in, twice as detailed)
      - Extends `s_waveformMaxZoom` from 10.0 → 80.0 (allows 1.25% zoom-out, 8× more overview)
      - Fixes `DlgPrefWaveform` combo box to handle sub-1.0 zoom entries without integer cast div-by-zero
      - Index↔zoom mapping generalised via `subOneCount` offset
    - Tested?: no
  - [x] **feature/2026.02feb.26-waveform-menu-order** - [#16046](https://github.com/mixxxdj/mixxx/pull/16046) - CHANGES_REQUESTED → addressed
    - Created: 2026-02-26, Last comment: 2026-05-26 (daschuer), Rebased: 2026-08-03, Updated: 2026-07-16
    - Next: Await re-review — addressed daschuer: removed lambda + alphabetical sort; order now set via `kValues` in `waveformwidgettype.h`
    - Specifics:
      - Reorders `kValues` in `WaveformWidgetType`: Simple, Filtered, HSV, RGB, Stacked, VSyncTest
      - Removes alphabetical combobox sort from `DlgPrefWaveform` — factory order is display order
      - Old: Simple, Filtered, HSV, VSyncTest, RGB, Stacked → New: Simple, Filtered, HSV, RGB, Stacked, VSyncTest
    - Tested?: yes (1203 tests pass)
  - [x] **feature/2026.02feb.20-simple-waveform-top-and-overview** - [#16021](https://github.com/mixxxdj/mixxx/pull/16021) - REVIEW_REQUIRED
    - Issue: [#16020](https://github.com/mixxxdj/mixxx/issues/16020)
    - Created: 2026-02-20, Last comment: 2026-05-28 (mxmilkiib, stale-bot reset), Rebased: 2026-08-03, Updated: 2026-07-16
    - Next: Address daschuer upgrade-path issue — RGB selected before update becomes Simple after; default should remain RGB; likely combobox position stored instead of enum value
    - Specifics:
      - Adds Simple as an overview waveform type (amplitude envelope, signal color, stereo mirrored)
      - Moves Simple to top of overview waveform combobox
      - daschuer CHANGES_REQUESTED: upgrade path alters waveform selection — RGB becomes Simple after update
      - ninomp inline: unused StackedRGB enum entry — mxmilkiib confirmed cruft from branch overlap
    - Tested?: yes (2026-07-16)
  - [x] **feature/2025.10oct.21-replace-libmodplug-with-libopenmpt** - [#15519](https://github.com/mixxxdj/mixxx/pull/15519) - DRAFT - REVIEW_REQUIRED
    - Issue: [#9862](https://github.com/mixxxdj/mixxx/issues/9862)
    - Created: 2025-10-25, Last comment: 2026-02-22 (stale-bot), Rebased: 2026-08-03, Updated: 2026-01-30
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
    - Created: 2025-10-20, Last comment: 2026-02-22 (stale-bot), Rebased: 2026-08-03, Updated: 2026-01-30
    - Next: Check recent comment, await review
    - Specifics:
      - PR marked stale (Jan 19 2026) — needs activity to unstale
      - Paint hotcues on scaled image (option b) not full-width — scaling happens in OverviewCache so fixed pixel widths don't translate
      - Remove `// MARK:` comments
      - Get cue data from delegate columns instead of SQL queries (done)
      - Review feedback from ronso0 on marker rendering approach
    - Tested?: no
  - [x] **feature/2025.11nov.17-deere-channel-mute-buttons** - [#15624](https://github.com/mixxxdj/mixxx/pull/15624) - DRAFT - REVIEW_REQUIRED
    - Issue: [#15623](https://github.com/mixxxdj/mixxx/issues/15623)
    - Created: 2025-11-17, Last comment: 2026-02-15, Rebased: 2026-08-03, Updated: 2026-02-15
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
  - [x] **feature/2025.11nov.16-playback-position-control** - [#15617](https://github.com/mixxxdj/mixxx/pull/15617) - REVIEW_REQUIRED
    - Issue: [#14288](https://github.com/mixxxdj/mixxx/issues/14288)
    - Created: 2025-11-16, Last comment: 2026-05-26 (mxmilkiib), Rebased: 2026-08-03, Updated: 2026-07-16
    - Next: Await re-review — all ronso0 CHANGES_REQUESTED addressed 2026-05-26; CI failures are pre-existing flaky (Flatpak aarch64 network timeout, macOS x64 BeatsTranslateTest SEGFAULT — unrelated to our changes)
    - Specifics:
      - daschuer (Feb 9): "this feature already exists" (pref option) — clarified: pref has no CO for runtime control
      - ronso0 confirmed: if it's about changing marker pos on the fly, the pref option has no CO
      - Adds `[Waveform],PlayMarkerPosition` ControlPotmeter (0.0–1.0) for runtime control
    - Tested?: no
- ⚠️ **Schema-Changing Branches (Excluded from Integration)**
  - [ ] **feature/2025.10oct.17-library-column-hotcue-count** - [#15462](https://github.com/mixxxdj/mixxx/pull/15462) - REVIEW_REQUIRED
    - Issue: [#15461](https://github.com/mixxxdj/mixxx/issues/15461)
    - Created: 2025-10-17, Last comment: 2026-02-22 (stale-bot), Rebased: 2026-08-03, Updated: 2026-01-30
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
  - [ ] **feature/2025.11nov.16-catalogue-number-column** - [#15616](https://github.com/mixxxdj/mixxx/pull/15616) - REVIEW_REQUIRED
    - Issue: [#12583](https://github.com/mixxxdj/mixxx/issues/12583)
    - Created: 2025-11-16, Last comment: 2026-02-15, Rebased: 2026-08-03, Updated: 2026-02-15
    - Next: Await review
    - Specifics:
      - acolombier left review comment 2026-02-14; replied 2026-02-15
      - Schema migration revision 40 — will conflict with hotcue-count branch (also schema change)
      - Removed from integration: schema change; keeping integration at upstream schema v40 until schema branches are stable
      - Uses MusicBrainz Picard tag mapping conventions
    - Tested?: no
- 🔵 **Local Only (No PR)**
  - [ ] **feature/2026.02feb.17-mono-waveform-option** — **SKIP_BRANCHES (build-broken)**
    - Created: 2026-02-17, Rebased: 2026-08-03, Updated: 2026-02-17
    - Test binary: [build-fail 2026-05-13]
    - Next: Fix base class — add `MonoSignal` to `WaveformRendererSignalBase::Option` enum and store `m_options` as protected member; both were expected by the branch but never committed or were lost in rebase
    - Specifics:
      - `waveformrendererfiltered.cpp` and `waveformrendererhsv.cpp` reference `m_options` (line 89/90) and `Option::MonoSignal` — neither declared anywhere in the current base class
      - Base class `WaveformRendererSignalBase` Option enum only has: `None`, `SplitStereoSignal`, `HighDetail`, `AllOptionsCombined`
      - Fix: add `MonoSignal = 0b100` to Option enum, store `m_options` in protected block, handle in both .cpp files
  - [x] **feature/2025.10oct.14-waveform-hotcue-label-options**
    - Created: 2025-10-14, Rebased: 2026-08-03, Updated: 2026-01-30
    - Next: Maintain for personal use
  - [x] **feature/2025.10oct.08-utf8-string-controls**
    - Dependency for: hotcue-labelling, hotcue-label-options
    - Created: 2025-10-08, Rebased: 2026-08-03, Updated: 2026-01-30
    - Next: Maintain for personal use (not for upstream)
  - [x] **feature/2025.09sep.25-hotcue-labelling**
    - Created: 2025-09-25, Rebased: 2026-08-03, Updated: 2026-02-20
    - Next: Maintain for personal use
  - [x] **feature/2025.11nov.05-deere-waveform-zoom-deck-colors**
    - Created: 2025-11-05, Rebased: 2026-08-03, Updated: 2026-01-30
    - Next: Merge to integration, decide if PR-worthy
    - Specifics:
      - Evaluate if the Deere-specific waveform zoom deck color change is worth a PR or remains personal use
      - Test visual appearance across deck configurations
  - [ ] **draft/2025.10oct.21-tracker-module-stems** — **SKIP_BRANCHES (build-broken)**
    - Created: 2025-10-21, Rebased: 2026-08-03, Updated: 2025-10-21
    - Test binary: [build-fail 2026-05-13]
    - Next: Investigate libopenmpt API — `openmpt::module::set_channel_mute_status` is absent from the stable C++ API (verified against libopenmpt 0.8.6); either the method does not exist in any release and the code must be rewritten using available API, or the branch was written against a proposed/unreleased API
    - Specifics:
      - `soundsourceopenmptstem.cpp` lines 216/221 call `m_pModule->set_channel_mute_status(ch, true/false)` which has no entry in the libopenmpt C++ headers
      - No alternative mute/channel-render method found in `openmpt::module` (0.8.6); C API also has no equivalent
      - Depends on replace-libmodplug-with-libopenmpt (#15519) being accepted first
      - Block until correct API is identified or available
  - [ ] **feature/2025.02feb.17-waveform-blend-customization** — LOCAL_ONLY — not in integration (branch name year typo: should be 2026)
    - Created: 2026-02-17, Rebased: 2026-08-03 (empty — no commits), Updated: unknown
    - Note: untracked worktree in mixxx-dev; branch has zero commits; placeholder or lost work
    - Next: Decide whether to populate, repurpose, or remove worktree
  - [ ] **bugfix/2026.02feb.19-wglwidget-xcb-resize-gap** — ABANDONED
    - Created: 2026-02-19, Updated: 2026-02-19
    - Next: Archive or delete branch
    - Specifics:
      - Attempted WA_PaintOnScreen on WGLWidget to reduce XCB resize gap
      - Abandoned: WGLWidget lacks paintEngine(), WA_PaintOnScreen causes heap corruption abort
      - Gap is inherent to QOpenGLWindow+createWindowContainer; no viable fix
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

## Integration Log

- Integration rebuilt 2026-02-19: applied waveform FBO + openglwindow resize fixes; fixed hotcue-labelling merge (missing setLabel/slotHotcueLabelChangeRequest); merged midi-makeinputhandler-null-engine bugfix (was missing, caused SIGSEGV/SIGABRT on controller shutdown)
- Integration rebuilt 2026-02-19 (second time): removed hotcue-count and catalogue-number branches — both require schema changes (v41, v42) that caused a cross-thread SQLite crash (SIGSEGV in BaseTrackCache::updateIndexWithQuery via Qt::DirectConnection on engine thread). Schema kept at upstream v40.
- Integration patched 2026-02-19: midi-makeinputhandler-null-engine fix was missing from the rebuild — caused repeated SIGSEGV/SIGABRT on controller shutdown (MidiControllerJSProxy::makeInputHandler null shared_ptr). Re-merged.
- Wayland root cause identified 2026-02-19: QOpenGLWindow subsurface resize blocks on compositor buffer realloc; workaround QT_QPA_PLATFORM=xcb
- XCB resize gap 2026-02-19: WA_PaintOnScreen approach abandoned — WGLWidget lacks paintEngine(), causes heap corruption abort; gap is inherent to QOpenGLWindow+createWindowContainer
- Integration updated 2026-02-20: added controlpickermenu-quickfx-deck-offset (#16019), fix-learning-wizard-from-prefs-button; fixed hotcue-labelling missing setLabel/slotHotcueLabelChangeRequest; build clean
- Integration updated 2026-02-21: merged simple-waveform-top-and-overview (Simple to top of main waveform list; Simple overview type)
- Integration updated 2026-02-21 (2): added Layered (LMH tail-to-tail) and Stems (stem channels) as main waveform types; build clean
- Integration updated 2026-02-21 (3): added CQT spectrogram main waveform type (frequency-band heatmap, showcqt-style hue mapping); build clean
- Integration updated 2026-02-21 (4): added Layered RGB (RGB colours, tail-to-tail); fixed CQT missing from mixxx-lib CMake target; build clean
- Integration patched 2026-02-21 (5): added hid-init-race-on-enumeration secondary patch (explicit hid_init() before hid_enumerate prevents concurrent re-init crash from background descriptor fetch threads); WaveformRendererCQT zero visualIncrementPerPixel guard
- Integration rebuilt 2026-02-28: rebased all branches on upstream/main (new upstream commits include stems model crash fix, MK2 LUT fixes, ringbuffer memory leak fix); resolved merge conflicts in waveformoverviewrenderer.cpp (StackedRGB vs Simple waveform ordering); added missing m_options member variables to waveformrendererfiltered.cpp and waveformrendererhsv.cpp; build clean
- Integration patched 2026-02-23: re-merged controller-wizard-quick-access (clazy range-loop-detach fix — std::as_const on all range-for loops over Qt containers); build clean
- Integration rebuilt 2026-03-11: rebased all branches on upstream/main (198 new upstream commits: fivefourths/fourfifths merged upstream as #16026, rating controls #15764, tuning field, BPM lock, key comparison effect, TS definitions); fivefourths and controlpickermenu-quickfx-deck-offset moved to Merged to Upstream; added waveform-menu-order (#16046); resolved conflicts in overviewtype.h + waveformoverviewrenderer.cpp/h + woverview.cpp (StackedRGB+Simple coexistence), dlgprefwaveform.cpp (moveWaveformTypeToIndex), cuecontrol.cpp/h (setLabel+slotHotcueLabelChangeRequest), dlgprefcontroller.h (showLearningWizard); build clean
- Integration rebuilt 2026-05-01: rebased all branches on upstream/main (349 new upstream commits: kbd-mapping-reload, sidebar expand-on-hover, Parser public method, overview leaveEvent fix, cue button DnD fixup, bulk controller async polling, pref sound stretch column, export loops to Engine DJ, QML enhanced settings, SQLite3 link fix); resolved conflicts in cuecontrol.cpp/h (setLabel+slotHotcueLabelChangeRequest), wmainmenubar.cpp/h (KeyboardEventFilter+Controller coexistence), dlgprefcontroller.h (showLearningWizard), waveformoverviewrenderer.cpp/h+woverview.cpp+overviewtype.h (StackedRGB+Simple coexistence), dlgprefwaveform.cpp (moveWaveformTypeToIndex lambda); build clean
- Integration updated 2026-05-11: merged upstream/main (13 new commits: Algoriddim djay support, Android output type name fix, beats preferences fix, 2.6 sync); resolved wmainmenubar.cpp/h conflict in controller-wizard-quick-access (KeyboardEventFilter+Controller coexistence); stripped cross-contamination commit from waveform-menu-order ("Add Simple overview waveform type" was a duplicate from simple-waveform branch); system protobuf upgraded v33→v34, stale test binaries block pre-push hook (not a code issue); feature branch pushes for controller-wizard and waveform-menu-order deferred pending test binary rebuild
- Integration updated 2026-05-26: rebased all 21 active branches on upstream/main; all test binaries up to date; 21/21 tests pass; integration + integrating pushed; GA CI triggered on origin/integrating
- Integration initiated 2026-06-18: 182 new upstream commits (SoundManager refactor, cmake4 fix, BPM-lock crash fix, non-latin char SoundSource test, FLAC recording fix, instantaneous-frequency detector, LateNightQML colour schemes + QML fixes, shout API warnings, library header assert crash fix); #16003 (midi-makeinputhandler-null-engine) merged upstream — moved to Merged to Upstream, worktree removed; simple-waveform-top-and-overview sentinel stale (updated 2026-05-28/29, needs re-test)
- Integration updated 2026-06-18: taglib 1.x→2.x system upgrade required full cmake cache wipe (CMakeCache.txt + libdjinterop ExternalProject stamp dirs) and Ninja reconfigure across all 21 worktrees; 21/21 rebuilt clean against taglib 2.3; 21/21 tests pass; integrating pushed (d4ac90d11b); GA CI queued
- Integration rebuilt 2026-07-16: rebased all 21 active branches on upstream/main; integration branch rebuilt from scratch (reset to upstream/main, merged all 20 [x] branches in order); resolved conflicts in overviewtype.h + waveformoverviewrenderer.cpp/h + woverview.cpp (StackedRGB+Simple coexistence), dlgprefwaveform.cpp (redundant sort+move code from simple-waveform dropped — waveform-menu-order already handles ordering), cuecontrol.cpp/h (setLabel+slotHotcueLabelChangeRequest), dlgprefcontroller.h (showLearningWizard); build clean (5m7s); 21/21 tests pass (42m14s); integration + integrating pushed (d318386f49); GA CI triggered — 3 failures (Windows: dependency checksum mismatch, Flatpak: xvfb-run exit 1, macOS: BeatsTranslateTest SEGFAULT — all infrastructure/flaky, none code-related); rerun requested
- wayland-opengl-resize-warning 2026-08-03: rebased onto upstream/2.6 per daschuer request (#16014 was main-based, PR retargeted to 2.6); [x] removed — excluded from main-based integration merges; addressed daschuer CHANGES_REQUESTED (dropped redundant MIXXX_USE_QOPENGL guard, warn-once static flag, linked #13814); replied to wayland-egl question; stale Jul-16 mixxx-test binary was hanging pre-push hook at 420s timeout — rebuilt against 2.6 base, 1174 tests pass; pushed (4557b82e49), PR marked ready for review; pre-commit CI then flagged two pre-existing long lines in 2.6's waveformwidgetfactory.cpp — wrapped locally, unpushed pending confirmation
- Integration rebuilt 2026-08-03: rebased 20 active branches on upstream/main (216 new commits incl. 2.6 sync, stem stacked waveforms, AutoDJ orientation); integration rebuilt from scratch (reset to upstream/main, merged 19 [x] branches — wayland excluded, now 2.6-based); resolved conflicts in dlgprefcontroller.h (showLearningWizard), overviewtype.h + waveformoverviewrenderer.cpp/h + woverview.cpp (StackedRGB+Simple coexistence — one resolution initially duplicated RGB enum, fixed), dlgprefwaveform.cpp (simple-waveform sort+move dropped, waveform-menu-order handles ordering); textured-waveform-fbo-resize + openglwindow-resize-repaint (no worktrees) rebased via temp worktrees; script gap fixed: build_all_tests now rebuilds binaries older than HEAD commit (stale binaries were previously tested after rebases); known gap: push_changed smart-diff compares against moving upstream/main so ALL branches push after any upstream sync (20 pushed) — needs range-diff-based comparison; ~/src/mixxx build dir needed taglib1 cache wipe (CMakeCache + libdjinterop stamps moved aside) before test binary rebuild; build clean; 20/20 tests pass; integration + integrating pushed (4d0590b836); GA CI triggered on origin/integrating

---

## TODO Summary

- **CHANGES_REQUESTED (7 PRs):** waveform-menu-order (#16046 — daschuer: don't sort combobox with lambda, adjust order in factory), simple-waveform-top-and-overview (#16021 — daschuer: upgrade path changes RGB to Simple, default should remain RGB), wayland-opengl-resize-warning (#16014 — daschuer: drop MIXXX_USE_QOPENGL guard, addressed 2026-08-03; rebased to 2.6, ready for review), playback-position-control (#15617 — ronso0: tooltip wording + null check pattern, addressed 2026-05-26), controller-wizard-quick-access (#15577 — ronso0: disconnect logic + range-for, addressed Feb 18), stacked-overview-waveform (#15516 — ronso0: remove redundant HSV/LMH renderers, addressed), restore-last-library-selection (#15460 — daschuer+ronso0: size check, programmatic string, match() instead of manual iteration, addressed 2026-02-28)
- **REVIEW_REQUIRED (8 PRs):** textured-waveform-fbo-resize (#16010), openglwindow-resize-repaint (#16012), hide-unenabled-controllers (#15580), deere-channel-mute-buttons (#15624, DRAFT), catalogue-number-column (#15616), replace-libmodplug-with-libopenmpt (#15519, DRAFT), hotcues-on-overview-waveform (#15514, DRAFT), library-column-hotcue-count (#15462, DRAFT)
- **Merged upstream:** midi-makeinputhandler-null-engine (#16003 — MERGED 2026-06-18; worktree removed)
- **CI status:** GA CI on origin/integrating failed (3 infra/flaky failures — Windows checksum mismatch, Flatpak xvfb-run, macOS BeatsTranslateTest SEGFAULT); rerun requested
- **Architecture changes needed:** replace-libmodplug-with-libopenmpt (daschuer: DSP to effect rack)
- **Draft / on hold:** deere-channel-mute-buttons (draft — needs broader plan)
- **Secondary patches:** hid-init-race-on-enumeration (evaluate for upstream PR)
- **Local dev decisions:** deere-waveform-zoom-deck-colors (PR-worthy?), tracker-module-stems (continue or archive?)

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
  - The "Rebased" date in INTEGRATION.md MUST be updated
- Rebased branches are NOT automatically pushed — use `--push-changed` to push only branches whose patch content differs from origin (avoids wasteful CI on pure rebases)
- Branches with unresolved conflicts SHOULD be noted for later attention
- After all branches are updated, the **Integration Merge Process** SHOULD be run

Automated via `./mixxx-integration-update-branches.sh` (run from `~/src/mixxx-dev/integration/`).

## Dev Helper Scripts

All scripts use the `mixxx-dev-` or `mixxx-integration-` filename prefix. All are committed to the `integration` branch and synced to the gist at the URL in the header.

| Script | Gist | Purpose |
|---|---|---|
| `mixxx-integration-update-branches.sh` | [5fb35c4](https://gist.github.com/mxmilkiib/5fb35c401736efed47ad7d78268c80b6) | Rebase all worktrees (no push), configure+build test binaries (parallel configure, serial build, `nice 15`), run test suite with per-branch sentinels for selective re-runs, smart-diff push (`--push-changed` — only content changes trigger CI), push `integration`/`integrating`, grand summary |
| `mixxx-dev-gdb-run.sh` | [da0d174](https://gist.github.com/mxmilkiib/da0d174d1bf80bd6d3f182d5e62186ec) | Launch Mixxx under GDB with `--developer --controller-debug --debug-assert-break`; auto-detects the `mixxx` binary; logs to timestamped file, discards on clean exit; sets `debuginfod enabled`, suppresses `SIG32`/`SIGPIPE`/`SIGUSR*` |

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
   ./mixxx-integration-update-branches.sh
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
   git merge <local-branch-name>
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
9. **Build and verify** — integration branch MUST be rebuilt after any branch is added or modified:

   Incremental rebuild (most common — after source changes):
   ```bash
   cmake --build /home/milkii/src/mixxx/build --target mixxx -- -j$(nproc --ignore=2)
   ```
   Full reconfigure (only needed when new branches add CMakeLists changes or new source files):
   ```bash
   cmake -B /home/milkii/src/mixxx/build -S /home/milkii/src/mixxx -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCCACHE_SUPPORT=ON
   cmake --build /home/milkii/src/mixxx/build --target mixxx -- -j$(nproc --ignore=2)
   ```
   Basic functionality SHOULD be tested after build.

10. **Sync to Gist**:
    ```bash
    gh gist edit 5fb35c401736efed47ad7d78268c80b6 --filename INTEGRATION.md INTEGRATION.md
    gh gist edit 5fb35c401736efed47ad7d78268c80b6 --filename mixxx-integration-update-branches.sh mixxx-integration-update-branches.sh
    ```

## Checking PR Status

```bash
gh pr view <PR-number>
gh pr list --repo mixxxdj/mixxx --author mxmilkiib
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
- Secondary patch entries use `Resolves-residual-from` or `Depends-on` instead of `Issue` to link to the primary branch

### Section Order
1. Awaiting Review from Others (feedback addressed, waiting on reviewer)
2. Secondary Patches
3. Bug Fixes — Open PRs (REVIEW_REQUIRED)
4. New Features — Open PRs (REVIEW_REQUIRED)
5. Schema-Changing Branches (Excluded from Integration)
6. Local Only (No PR)
7. Merged to Upstream

### Summary Line
**When updating integration**: Update the "Last updated" date at the top of this file.

Update the summary line at the top when adding/removing branches:
```markdown
**Summary**: X need attention, Y awaiting review, Z schema-excluded, W merged upstream, V local-only, U secondary patch
```
