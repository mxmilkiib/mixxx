# Mixxx Multi-PR Dev & Test Build (AI Integration Skill + State)

> Last updated: 2026-08-20
> URL: https://gist.github.com/mxmilkiib/5fb35c401736efed47ad7d78268c80b6
> [RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119)

## Rules

- **Purpose**: this living document is a prompt file that includes the rules and procedures, plus state, for an AI skill to manage multiple feature and bugfix branches, as well as a combined PR test build of Mixxx
  - a script rebases all branches, builds test binaries, and runs the test suite.
  - **Last updated**: The "Last updated" date at the top of this file MUST be updated whenever this file is edited. It should remain as only a date.
  - **Gist sync**: `INTEGRATION.md` (this file), `mixxx-milkii-integration-update-branches.sh`, `mixxx-milkii-integration-pre-push.sh`, and `mixxx-milkii-integration-gdb-run.sh` MUST be updated and synced to Gist as the workflow evolve.
    ```bash
    gh gist edit 5fb35c401736efed47ad7d78268c80b6 --filename INTEGRATION.md INTEGRATION.md
    gh gist edit 5fb35c401736efed47ad7d78268c80b6 --filename mixxx-milkii-integration-update-branches.sh mixxx-milkii-integration-update-branches.sh
    gh gist edit 5fb35c401736efed47ad7d78268c80b6 --filename mixxx-milkii-integration-pre-push.sh mixxx-milkii-integration-pre-push.sh
    gh gist edit 5fb35c401736efed47ad7d78268c80b6 --filename mixxx-milkii-integration-gdb-run.sh mixxx-milkii-integration-gdb-run.sh
    ```
  - **Cross-model review**: This document, the scripts, and the branch outline MUST be cross-checked against ground truth by a *different* model from the one that last wrote them, at least every several sessions or whenever a claim in the doc is questionable. Self-review by the authoring model reliably misses its own confabulations — status lines get carried forward, "auto-promoted" gets written for something never observed, dates get copied instead of queried. Anything the checking model cannot verify MUST be marked UNVERIFIED rather than left as an assertion.


- **Dual dir**: all source trees share the SAME `.git` database rooted at `~/src/mixxx/.git`.
  - `~/src/mixxx/` — checked out on `main`; synced with `mixxxdj/mixxx` main for testing upstream
  - `~/src/mixxx-dev/integration/` — checked out on `integration`; all `[x]`-marked branches merged here; script and helper files live here; this is where `./mixxx-milkii-integration-update-branches.sh` is run from;
  - `~/src/mixxx-dev/<branch>/` — individual feature/bugfix Git worktrees
  - Registered worktrees are not separate clones — `git log`, `git branch -a`, etc. show all branches from any path.
  - **Stability**: This dual setup SHOULD provide consistency for a stable bleeding-edge build without interference from local development.
- **Main sync**: The project repo MUST maintain a `main` branch that is synced with `mixxxdj/mixxx` main. `origin/main` MUST be kept as a fast-forward mirror of `upstream/main` — run `git push --no-verify origin main` after every `git fetch upstream && git merge upstream/main` on `main`.
  - **Main read-only**: The `main` branch MUST NOT receive any local commits — not INTEGRATION.md updates, not patches, nothing. All commits go on `integration` or a worktree branch. Any stray commits on `main` MUST be removed by force-pushing the clean `upstream/main` tip.
  - **Dev location**: All individual branch development should be done using the `mixxx-dev` worktree directory
  - **Rebase hygiene**: All branches SHOULD be kept up-to-date and rebased with `mixxxdj/mixxx` main to minimize merge conflicts, except merged branches
  - **Rebase first**: A branch MUST be rebased as an initial step before any new change is made to said branch


- **Worktrees**: All development MUST use worktrees, keeping individual branches compartmentalised and clean for upstream PRs.
  - **Branch tiers**: The `mixxx` repo MUST maintain three promotion-chain branches:
    - `integration` — working merge/scratchpad branch, may break; script operates here;
      - rebuilt from scratch on each run by merging `upstream/main` then all `[x]`-marked worktree branches in order
      - may be broken at any time, intentionally ephemeral and MUST NOT be treated as stable.
    - `integrating` — a locally-tested-clean staging gate 
      - promoted from `integration` only after ALL non-skipped worktrees have passing test suites (`--push-integrating`);
      - triggers GitHub Action CI testing, running a full build + unit test suite on a clean runner with no shared cache, catching missing-dependency or build-flag issues invisible to local tests.
    - `integrated` — CI-confirmed-clean tier;
      - promoted from `integrating` only after GA CI Linux/macOS/Windows builds pass on `origin/integrating` (`--promote-integrated`);
      - the confirmed-clean consumption tier and the only one the Manjaro release pipeline packages.
      - does NOT mean "guaranteed to build everywhere" — locally-filtered `KNOWN_FAILING` suites and `KNOWN_INFRA_FAILURES` jobs are excluded from both gates.
      - `build/mixxx` here is the daily-driver binary
  - **No worktree, no coverage**: The converse also holds and is easier to miss. `rebase_all`, `build_all_tests` and `run_tests_serial` all iterate `${MIXXX_DEV}/*/`, so a branch with no worktree is invisible to the script — never rebased, never built, never tested — while still being merged into `integration` by `remerge_integration()`.
    - An `[x]`-marked branch MUST have a worktree, or be explicitly listed as refs-only in the outline so the gap is visible.


- **Standalone branches**: Each feature/fix branch SHOULD work standalone without depending on other local branches (except where noted)
  - **Single-branch build**: When the user asks to build a specific branch or worktree, ALWAYS build the full `mixxx` executable (`cmake --build <worktree>/build --target mixxx`), NOT just `mixxx-test`. The test binary is built separately by the integration script; a user-requested build means they want a runnable binary. Build command: `CCACHE_BASEDIR=~/src/mixxx-dev/<name> nice -n 15 cmake --build ~/src/mixxx-dev/<name>/build --target mixxx -j$(nproc --ignore=2)`.
  - **Isolated test profiles**: When running a worktree build for manual testing, use `--settingsPath /tmp/mixxx-test-<branch-name>` to isolate config, library DB, and state from the main profile. Mixxx auto-creates the directory. Run: `<worktree>/build/mixxx --settingsPath /tmp/mixxx-test-<branch-name>`. Add `--controller-debug --developer` for diagnostic logging.



- **Outline currency**: The integration status outline MUST reflect the state of all branches, related issues, PRs, and dates, and MUST be updated after changes are committed — PR URLs SHOULD be checked first to catch new feedback
  - **Sections**: Feature and fix branches should be in the correct outline sections
  - **Issues**: Most branches MAY have related upstream issues; related issues SHOULD be listed in the outline
  - **Dates**: Dates for branch creation, last PR comment, and last update MUST be recorded in the status outline
  - **Dependencies**: Any fix or feature branch that relies on another local branch MUST be noted in the Branch Dependencies section
- **Non-interactive git**: Git operations MUST be non-interactive using `GIT_EDITOR=true` and `GIT_PAGER=cat` to avoid vim/editor prompts
- **File edits**: All file changes to tracked files MUST be made with the IDE's `edit`/`write_to_file` tools (showing diffs in the editor), NEVER via shell commands (`echo >`, `tee`, `sed -i`, etc.) which bypass the diff view entirely.




- **Clean commits**: A branch in `mixxx-dev` MUST have clean commits before first being linked with a GitHub PR
  - **Commit messages**: Commit messages must not be too verbose, and should be concise and descriptive.
- **Code quality**: Code quality MUST be verified before pushing — code should be proper, straight to the point, robust, and follow Mixxx coding style. This is achieved with a pre-commit hook to check the style of the code.
- **History**: Feature/fix branch history MUST NOT be rewritten (no squash, no interactive rebase) without explicit permission from Milkii. "Complete" means the upstream PR has been merged or the branch has been deliberately closed. The integration branch MAY have merge commits.
- **Incremental PRs**: Changes to `mixxxdj/mixxx` PRs MUST be incremental so as to be easy to review, and MUST NOT completely reformulate a system in a single commit
- **Secondary patches**: Secondary patches are small fixes that either (a) resolve a residual problem that only became visible after a larger fix landed, or (b) are a prerequisite that a main fix branch depends on. They MUST be tracked in the **Secondary Patches** section of the outline, with a `Depends-on` or `Resolves-residual-from` note linking them to the related primary branch
- **Secondary patch upstream**: A secondary patch SHOULD be submitted upstream independently if it stands alone; if it only makes sense in context of the primary fix, it MAY be folded into that PR




### Preventing Cross-Branch Contamination

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





- **PR head branch identity**: The local branch checked out in a worktree MUST be the same ref name as the head branch of its upstream PR. If they differ, `--push-changed` pushes a branch nobody is reviewing and the PR silently rots. Verify with `gh pr view <n> --repo mixxxdj/mixxx --json headRefName`. Four PRs are currently in this state — see the outline entries flagged `PR head MISMATCH`.
- **Personal-only**: Some features (UTF-8 string controls) MUST NOT be submitted to `mixxxdj/mixxx` upstream as they are for personal use only


- **Push permission**: Permission MUST be sought from the user before pushing commits to GitHub. Once the user has confirmed a push in a session, further pushes in that same session MAY proceed without asking again, to reduce friction.

- **Pre-push hook timeout**: The hook runs `timeout 420 ./mixxx-test` to prevent indefinite hangs. If the timeout fires, it reports the last test name and blocks the push. Investigate the hanging test by running it in isolation first (`./mixxx-test --gtest_filter=SuiteName`) — if it passes alone, it is a state-poisoning issue from a preceding test.



- **"Updating" the system**: When the user asks to "update" or "run integration", or says the system has been updated, this MUST include all of the following post-update checks and tasks in order:

- 1. **Commit pending INTEGRATION.md changes** (if any) before starting:
   ```bash
   git add INTEGRATION.md && git commit -m "update INTEGRATION.md before integration"
   ```
   - **mixxx-milkii-integration-update-branches.sh**: The script MUST exist as a committed file in the `integration` branch and MUST be run from `~/src/mixxx-dev/integration/`. All `${MIXXX_DEV}/*/` loops in the script MUST guard with `[[ "$name" =~ ^[0-9]{4}\. ]] || continue` so promotion-chain worktrees (`integration`, `integrating`, `integrated`) — which lack the `YYYY.` date prefix — are never treated as feature branches. It MUST skip worktrees whose branches have been merged upstream, closed, or abandoned.


- 2. **Promotion check** — At the start of any session, verify promotion is working:
  - **Promotion currency**: `integrated` MUST NOT lag behind a passing `integrating`, and MUST NOT run ahead of it either. Promotion is now automated via `.github/workflows/auto-promote.yml` workflow — when `develop.yml` CI completes on `integrating`, it checks job results and promotes automatically if all failures are known infra (`KNOWN_INFRA_FAILURES`, same patterns as the script), and if all failures are known infra/flaky (or the run passed cleanly), promotes `integrating` → `integrated` via `gh api` ref update. 
  - **Invariant**: `integrated` is a CI-confirmed snapshot of `integrating` — it MUST always be an ancestor-or-equal of `origin/integrating`, never ahead. `integrating` advances forward; `integrated` is the point `integrating` had reached when CI last passed. Verify with `git rev-list --left-right --count origin/integrating...origin/integrated`; a non-zero right-hand count means a commit reached `integrated` without passing the CI gate.
    - **Out-of-band commits**: infrastructure commits (workflow files, CI config) MAY be pushed directly to `integrated` because `workflow_run` triggers only fire for workflows on the default branch. Such commits MUST also be pushed to `integrating` to restore the invariant — otherwise the next auto-promote force-update would land `integrated` at a SHA that lacks the workflow file, silently breaking the trigger chain.
    - **Auto-promote survival**: `auto-promote.yml` MUST exist on `integrating` as well as on `integrated`. Auto-promote force-updates `integrated` to the `integrating` SHA; if the workflow file is only on `integrated`, the first successful promotion removes it and the trigger never fires again.
    - Check with `gh run list --workflow auto-promote.yml --repo mxmilkiib/mixxx --limit 1 --json status,conclusion`; empty output means "never ran", which is NOT the same as "working".
  - If auto-promote failed or was blocked by an unknown failure, investigate and manually run `--promote-integrated` after confirming the failure is infra.
  - Letting `integrated` sit stale means the Manjaro release pipeline is packaging an out-of-date build, letting it run ahead means it is packaging something CI never saw.

- 3. **Integration freshness check** — for every `[x]` branch, `git merge-base --is-ancestor <branch> integration`. A branch that is not an ancestor was rebased after it was merged, so `integration` is carrying a stale copy. Content may still be equivalent (`git cherry integration <branch>` shows `+` only for genuinely unapplied commits) but the base is old.


- 4. **Test binary staleness**: After any system library upgrade (e.g. protobuf, Qt, libstdc++), the `build/mixxx-test` binary in each worktree MUST be rebuilt before pushing — stale binaries will fail the pre-push hook with a dynamic linker error, not a test failure. Run `ldd <worktree>/build/mixxx-test | grep 'not found'` to detect staleness without rebuilding. Use `mixxx-milkii-integration-update-branches.sh --rebuild-tests` to rebuild all stale test binaries serially.


- 5. **Fetch upstream/main and sync**
  - `git fetch upstream && git rev-list --left-right --count upstream/main...main`;
  - if the left count is non-zero, `main` has drifted and MUST be fast-forwarded and pushed to `origin`.

  - **Branch merged** Check all `[x]` branches: for each, verify whether its commits are already present in `upstream/main` (`git log upstream/main --oneline | grep <keyword>`); if fully merged, move the entry to the "Merged to Upstream" section, remove the `[x]` marker, and record the merge date — do this BEFORE rebasing or rebuilding so merged branches are excluded from both


- 6. Check all open PRs for new review feedback (CHANGES_REQUESTED, new comments) and update INTEGRATION.md statuses accordingly
    - `gh pr view <PR-number>`
    - `gh pr list --repo mixxxdj/mixxx --author mxmilkiib`


- 7. **Rebase + remerge integration + build + test + push** — all via `--rebase-merge-test-push`
  - stash any WIP first;
  - clean any branches with accidental INTEGRATION.md or other cruft commits.
  - **INTEGRATION_BRANCHES confirmation**: before running `--rebase-merge-test-push`, verify the `INTEGRATION_BRANCHES` array in the script matches the `[x]`-marked branches in the outline below. Update the array if branches have been added or removed from integration.
  - automated via `./mixxx-milkii-integration-update-branches.sh --rebase-merge-test-push` (run from `~/src/mixxx-dev/integration/`)
    - the script: (1) rebases all worktrees, (2) resets `integration` to `upstream/main` and merges all `INTEGRATION_BRANCHES` in order, (3) builds test binaries, (4) runs tests, (5) pushes `integration`/`integrating`.
    - a merge conflict in step 2 is fatal — the script exits non-zero with a CONFLICT message. Resolve manually in the integration worktree, then re-run.
    - for manual rebase-only, run `git rebase upstream/main` in each worktree.
    - for standalone integration remerge, run `--remerge-integration` (reset + merge only, skip if clean, no rebase/build/test/push).
  
  - **Integration re-merge after rebase**: `--rebase-merge-test-push` now rebuilds `integration` (reset to `upstream/main`, re-merge all `INTEGRATION_BRANCHES`) as part of its flow, so the integration branch is always fresh after a run. Previously this was a manual step that could be skipped, leaving `integration` carrying stale pre-rebase copies. Use `git cherry integration <branch>` to tell cosmetic staleness (all `-`) from real missing content (any `+`).
  - **Local-only backup**: All local-only branches MUST be pushed to `origin` (`mxmilkiib/mixxx`) for off-machine backup, even if they will never be PRed upstream. All worktrees share a single `.git` directory — losing it means losing every unpushed branch.
  - **PERSONAL_ONLY dependency chains**: When rebasing branches that form a PERSONAL_ONLY dependency chain, the dependency root MUST be rebased first, then each dependent in topological order. If the root bitrots or conflicts, all dependents are broken until the root is fixed.


  - **Monitoring progress**: `mixxx-milkii-integration-update-branches.sh --rebase-merge-test-push` (or `--rebase-merge-test-push-promote`) writes timestamped phase/branch updates to `STATUS_FILE=/tmp/mixxx-integration-status`. In a second terminal: `tail -f /tmp/mixxx-integration-status`. Individual test suite logs: `tail -f /tmp/mixxx-test-logs/<worktree>.log`. During test runs, a heartbeat prints test count every 30 s to the main terminal so it never appears frozen. During CI polling (`--promote-integrated` or `--rebase-merge-test-push-promote`), per-job status is printed with OK/FAIL/CXL/SKIP/.. icons each time a job state changes.

- 8. **CI-conscious pushing**:
  - feature branch force-pushes to `origin` trigger full CI matrix on `mixxxdj/mixxx`.
  - a pure rebase (same patch, different base) has zero CI value — it wastes shared runner time and annoys reviewers who monitor PR activity.
  - so rebased branches are NOT automatically pushed
  - if any PR branches have actual content changes (review feedback addressed, conflict resolutions), run `--push-changed` to push only those branches whose patch-ids differ from origin. The script compares `git patch-id` of `upstream/main..HEAD` vs `upstream/main..origin/<branch>` — this is base-independent, so a pure rebase (same patches, different base) produces identical patch-ids and is correctly skipped.
  - manual pushes (e.g. after addressing review feedback) bypass this — push directly from the worktree as needed.





  - **Conflict resolution**: When resolving merge conflicts — whether during rebases or integration merges — conflicts MUST be carefully resolved and the operation continued non-interactively. Common issues:
    - Schema revisions: increment version numbers
    - Enum IDs in `trackmodel.h`: assign unique IDs
    - Header declarations vs implementations: keep both sides' additions

  - Update "Rebased" and "Updated" dates in the outline to today
  - Branches with unresolved conflicts SHOULD be noted for later attention
  


- Merge Order for Overlapping Source Files

Some active branches modify the same source files. The script merges branches in worktree directory order (alphabetical by date prefix), which happens to be correct for these overlaps. If the order is ever changed, the following dependencies MUST be respected:

**`src/waveform/renderers/waveformoverviewrenderer.cpp` and `.h`** — 3 branches touch these:
1. `2025.10oct.20-hotcues-on-overview-waveform` (adds hotcue rendering to overview)
2. `2025.10oct.21-stacked-overview-waveform` (adds StackedRGB enum + renderer)
3. `2026.02feb.20-simple-waveform-top-and-overview` (adds Simple overview type)

Each builds on the previous — merging out of order will cause conflict resolutions that silently drop changes.

**`src/preferences/dialog/dlgprefwaveform.cpp`** — 4 branches touch this:
1. `2025.10oct.21-stacked-overview-waveform` (adds Stacked to combobox)
2. `2026.02feb.20-simple-waveform-top-and-overview` (adds Simple to top of combobox)
3. `2026.02feb.26-waveform-menu-order` (reorders combobox via kValues, removes sort lambda)
4. `2026.05may.03-extend-waveform-zoom-range` (extends zoom range entries)

waveform-menu-order MUST merge after simple-waveform — it removes the sort lambda that simple-waveform relies on being absent. The current alphabetical order satisfies this.

**`src/library/library.cpp`, `src/library/sidebarmodel.cpp`, `src/library/sidebarmodel.h`** — only `restore-last-library-selection` touches these. No ordering concern, but if the branch is rewritten after being merged into integration, the next `--rebase-merge-test-push` rebuild may resolve merge conflicts in favour of the stale already-merged version. After rewriting a branch, re-merge it manually into `integration` before running `--rebase-merge-test-push`.


- 9. **Integration remerge** — automated by `--rebase-merge-test-push` (and standalone `--remerge-integration`)
  - **Schema exclusion**: Branches that introduce database schema migrations MUST NOT be merged into the integration branch unless all schema-changing branches use compatible, non-conflicting revision numbers. Schema branches are tracked in a dedicated "Schema-Changing Branches" section of the outline. They MUST NOT be listed in `INTEGRATION_BRANCHES`.
  - the script resets `integration` to `upstream/main`, then merges each branch in `INTEGRATION_BRANCHES` in order with `git merge --no-edit`
  - **Skip-when-clean**: if `upstream/main` is an ancestor of `integration` AND all `INTEGRATION_BRANCHES` are ancestors, the remerge is skipped (integration is current). To force a remerge after removing a branch from `INTEGRATION_BRANCHES`, reset integration first: `git -C ~/src/mixxx-dev/integration reset --hard upstream/main`
  - **No cherry-pick**: ALWAYS use `git merge` to bring branches into integration, NEVER `git cherry-pick` — cherry-picking creates duplicate commits with different SHAs, severs the branch relationship, makes bisect/revert unreliable, and hides what is actually in the build from `git log`
  - **Merge conflicts**: if a merge conflicts, the script aborts that merge, prints a CONFLICT message, and exits non-zero. Resolve manually in the integration worktree (`cd ~/src/mixxx-dev/integration && git merge --no-edit <branch>`, resolve, `git add`, `git commit`). **git rerere** (enabled in repo config) records the resolution — subsequent remerges auto-resolve the same conflict. Then re-run `--rebase-merge-test-push` or continue with `--build-all-tests && --run-tests && --push-integrating`.
  - **Conflict resolution policy**: conflicts between branches MUST be resolved in the  integration merge, NOT in the branch code. Branches are for upstream PRs and MUST stay clean. If branch B needs to accommodate branch A, that accommodation belongs in the integration merge (preserved by rerere), not in B's commits — otherwise B's upstream PR carries unnecessary structure if A is never accepted.
  - **INTEGRATION_BRANCHES array**: the ordered list of branch ref names to merge. MUST match the `[x]`-marked branches in the outline. Verify before each run and update when branches are added or removed from integration.
  - full reconfigure - only needed when new branches add CMakeLists changes or new source files:
   ```bash
   cmake -B ~/src/mixxx-dev/integration/build -S ~/src/mixxx-dev/integration -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCCACHE_SUPPORT=ON```
   - the main build command, which is run without reconfigure for an incremental rebuild (most common — after source changes):
   ```bash
   CCACHE_BASEDIR=~/src/mixxx-dev/integration nice -n 15 cmake --build ~/src/mixxx-dev/integration/build --target mixxx -- -j$(nproc --ignore=2)
   ```
  - **Build type**: All worktree builds MUST use `CMAKE_BUILD_TYPE=RelWithDebInfo`. Debug builds abort on `DEBUG_ASSERT` calls, causing tests to crash with non-zero exit that looks like a test failure (e.g. `SoundSourceProxyTest.openEmptyFile` firing `FileInfo::canonicalLocation` assert). Release builds suppress the crash but lose debug symbols. `RelWithDebInfo` is the correct balance. Check: `grep CMAKE_BUILD_TYPE <worktree>/build/CMakeCache.txt`. Reconfigure with: `cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo <worktree>/build`.

- **Build parallelism**: NEVER launch multiple full worktree builds simultaneously — 5 × `-j$(nproc)` on a 32-core machine means 150 competing jobs and effectively no progress. Worktree builds MUST be run serially using `-j$(nproc --ignore=2)`. With ccache + CCACHE_BASEDIR correctly set, each subsequent build is mostly cache hits making serial runs fast.
- **Killing builds**: `pkill -f cmake` only kills the cmake wrapper — ninja/make/cc1plus children survive and saturate the CPU. To kill a full build tree: `ps aux | grep -E 'cc1plus|ninja|/usr/bin/make' | grep -v grep | awk '{print $2}' | xargs -r kill -9`. In the script, Ctrl-C triggers a `kill 0` trap that kills the whole process group cleanly.
- **ccache**: All worktree builds MUST be configured with `-DCCACHE_SUPPORT=ON`. Cache size SHOULD be 15 GB or more. To enable on an existing build: `cmake -DCCACHE_SUPPORT=ON <worktree>/build` (in-place reconfigure).
  - **Cross-worktree sharing requires `CCACHE_BASEDIR`**: worktrees are at different paths, so preprocessor `#line` markers embed different absolute paths in the hash. Setting `CCACHE_BASEDIR=<worktree-root>` at build time strips that prefix, making paths relative — identical upstream files then produce the same hash across worktrees. This is set automatically by `mixxx-milkii-integration-update-branches.sh`; manual builds MUST also set it: `CCACHE_BASEDIR=~/src/mixxx-dev/<name> cmake --build ...`.
  - `hash_dir = false` in `~/.config/ccache/ccache.conf` prevents the build directory path from entering the hash (complementary to CCACHE_BASEDIR). Both settings are needed for robust cross-worktree sharing.
- **Skip list vs integration markers**: `SKIP_BRANCHES` in `mixxx-milkii-integration-update-branches.sh` covers only branches whose worktrees are removed, merged, or abandoned — these are skipped in ALL operations. PERSONAL_ONLY, LOCAL_ONLY, and schema-excluded branches are NOT in SKIP_BRANCHES; they are still rebased and tested. They are excluded only from integration merges, tracked via `[ ]` vs `[x]` markers in the Branch Status Outline (manual step).

- 10. **Test binary completeness**: Before `--push-integrating` can succeed, ALL non-skipped worktree branches MUST have a `build/mixxx-test` binary AND each must have a per-branch sentinel with an acceptable status for its current HEAD. `--rebase-merge-test-push` uses `--build-all-tests` which: (1) launches all cmake configures **in parallel** (configure is I/O-bound; 16 configures take ~5s instead of ~70s serial), then (2) builds `mixxx-test` serially with `-j(nproc-2)`, then (3) prints a `ccache -s` summary. Standalone: `--build-all-tests` then `--run-tests`. The script lists all blocking branches when `--push-integrating` is blocked. `--rebuild-tests` still exists but only handles stale binaries (ldd-detected) — it does NOT configure unconfigured branches.
  - **Per-branch test status**: The sentinel files are authoritative for automated test state; do NOT mirror them per-entry, that only creates a second copy to fall out of date. `[build-fail YYYY-MM-DD]` on build-broken branches. The separate `Tested?:` field means something different: *manually* tested by Milkii on a real DJ setup, which is what the Mixxx contribution policy requires before a PR is opened. Sentinel `pass` does not make `Tested?: yes` true.
  - **Test serialisation**: Local tests MUST be run serially (`run_tests_serial`), not in parallel. Multiple concurrent `mixxx-test` processes share the same audio device mocks, ControlObject registry, and SQLite test databases — parallel runs cause non-deterministic failures and resource exhaustion. Serial execution ensures reproducible results. Build compilation IS parallel within each worktree (`-j$(nproc --ignore=2)`) and configure steps are parallelised across worktrees.
  - **Per-branch test sentinel**: After each test run, `run_tests_serial` writes `~/.cache/mixxx-integration/<name>.tested` containing `<branch-HEAD-SHA> <status>` where status is one of:
    - `pass` — clean tree, has commits ahead of upstream, tests pass
    - `fail` — tests failed
    - `nocommits` — no commits ahead of upstream/main; nothing to test, non-blocking
    - `dirty-pass` — dirty working tree, tests pass (unreliable — binary may include uncommitted source; always re-tested next run)
    - `dirty-fail` — dirty working tree, tests failed
    Sentinels survive reboots (unlike `/tmp/`). `run_tests_serial` is **selective**: branches whose sentinel matches their current HEAD SHA and status is `pass` are skipped, so re-runs after a single branch rebase only re-test that branch (~3 min vs ~65 min). `dirty-pass` is always re-tested because uncommitted state may have changed. `push_integrating` Gate 2 checks each branch's sentinel individually — accepts `pass` and `dirty-pass` (with warning), blocks on `fail` and `dirty-fail`, skips `nocommits` (non-blocking). A global summary sentinel is also written to `~/.cache/mixxx-integration/tests-passed` for auditing. Invalidation is automatic: when a branch rebases its HEAD SHA changes, making the sentinel stale.
  - **Stale sentinel check** — for any branch whose sentinel SHA (`~/.cache/mixxx-integration/<name>.tested`) does not match its current `git rev-parse HEAD`, note it as needing a re-test before the next `--push-integrating`.
  - **Commitless branches**: branches with no commits ahead of `upstream/main` get a `nocommits` sentinel and are skipped by `run_tests_serial` (nothing to test). Gate 2 treats `nocommits` as non-blocking — the branch has no work to fail. This prevents the previous false-pass where a sentinel recorded `pass` against upstream code because HEAD was `main`/`upstream/main` for an uncommitted worktree.

  - All local tests must pass across ALL non-skipped worktrees.
  - Run `--build-all-tests` to configure cmake and build any missing binaries (also rebuilds stale ones), then `--run-tests` to confirm 0 failures. Both steps are done automatically by `--rebase-merge-test-push` (or `--rebase-merge-test-push-promote` to also poll CI and promote in one command).
  - Once clean, run `--push-integrating` to promote `integration` → `origin/integrating`. This triggers GA CI.


  - **Upstream test filter scope**: When filtering known-failing upstream tests, filter the ENTIRE affected test suite (e.g. `ControllerScriptEngineLegacyTimerTest.*`) not just the specific failing cases. Individual tests in the suite that nominally pass can still corrupt shared QTimer/ControlObject state, causing unrelated downstream tests (e.g. `MidiMappings/MappingTestFixture`) to hang indefinitely.
  - Root cause: `coTimerId ControlPotmeter max=50` clamps any QTimer ID > 50, producing collisions that prevent timer callbacks from firing.
  - Filtering the entire suite prevents state poisoning. Remove when upstream fix lands.
  - `AdjustReplayGainTest.AdjustReplayGainUpdatesPregain|MidiMappings/.*|HidMappings/.*|BulkMappings/.*|ControllerScriptEngineLegacyTest.*|ControllerScriptEngineLegacyTimerTest.*`. These suites are excluded for the same state-poisoning / known-failing reasons documented in the **Upstream test filter scope** and **Pre-push hook timeout** rules. A test failure fails the workflow before any package is produced.
  - Wait for GA CI on `origin/integrating`. The `auto-promote.yml` workflow fires automatically when CI completes and promotes `integrating` → `integrated` if all failures are known infra/flaky.
    - CI failures matching `KNOWN_INFRA_FAILURES` are treated as infra/flaky and do not block promotion. the list has four patterns:
      - Flatpak (xvfb-run exit 1)
      - Windows VS x64 (dependency checksum mismatch)
      - Windows VS ARM64 (AdjustReplayGainTest SEGFAULT)
      - macOS x64 (BeatsTranslateTest SEGFAULT)

  - If any failure is unknown, auto-promote blocks; investigate whether it is pre-existing on `upstream/main` or integration-introduced, and add the job pattern to `KNOWN_INFRA_FAILURES` (in both the script and `auto-promote.yml`) only after confirming it is infra/flaky.
  - For manual control, `--promote-integrated` polls GA CI with per-job status reporting and promotes in one command; `--rebase-merge-test-push-promote` chains steps 6–9 (rebase + remerge integration + build + test + push + CI poll + promote) into a single command.


- 11. **Update INTEGRATION.md**:
   - Update the summary line counts


## Manjaro/Arch Release Pipeline

- **Default branch**: The fork's default branch is `integrated` (changed from `main` via `gh api repos/mxmilkiib/mixxx -X PATCH --field default_branch=integrated`). This is required because `workflow_run` triggers only fire for workflows defined on the default branch. `main` remains a read-only mirror of `upstream/main` but is no longer the default.
- **Manjaro release pipeline**: `.github/workflows/manjaro-release.yml` is a release-packaging workflow distinct from the `build.yml` CI matrix. it produces an installable Manjaro/Arch package from the CI-confirmed `integrated` branch and publishes it as a pre-release GitHub Release on `mxmilkiib/mixxx`.
  - **Release workflow**: The upstream `release.yml` workflow (triggers on push to `main`, runs full build matrix with `publish: true` + Flatpak publishing) is disabled on the fork via `gh workflow disable 169770132 --repo mxmilkiib/mixxx` — `main` is a mirror, not a release branch, so running the release pipeline on it would waste runner time and fail on missing publishing secrets. Re-enable with `gh workflow enable 169770132 --repo mxmilkiib/mixxx` only if the fork ever needs to act as a release source.
- **Trigger**
  - `push` to `integrated` — fires automatically on every successful `--promote-integrated`.
  - `workflow_dispatch` — manual run from the Actions UI against any branch/SHA.
  - Only the CI-confirmed tier is packaged; `integration` and `integrating` pushes do NOT trigger it.
  - `concurrency: group: manjaro-release` with `cancel-in-progress: true` ensures rapid successive `integrated` promotions do not stack overlapping package builds; the newest promotion wins.
- **Build environment**
  - Runner: `ubuntu-24.04` with a `manjarolinux/base:latest` container (`--privileged`).
  - Base deps installed via `pacman -Syu`: `base-devel git cmake ninja ccache sudo`.
  - `makepkg` refuses to run as root, so a non-root `builder` user (in `wheel`, passwordless sudo) is created. All `makepkg` invocations run as `builder` via `su builder -c`.
  - Mixxx build deps installed from the Manjaro repos: protobuf, vamp-plugin-sdk, chromaprint, libid3tag, rubberband, soundtouch, lame, libogg, libmad, libvorbis, libmp4v2, faad2, opusfile, wavpack, libshout, libsndfile, portmidi, portaudio, sqlite, upower, lilv, libebur128, libopenmpt, qt6-declarative, qtkeychain-qt6, qt6-svg, qt6-shadertools, qt6-5compat, qt6-multimedia-ffmpeg, qt6-scxml, microsoft-gsl, hidapi, ffmpeg, fftw, flac, glu, pipewire, pipewire-jack, libusb, jsoncpp, gtest, gmock.
  - `taglib1` is NOT in the Manjaro repos and is built from AUR (`https://aur.archlinux.org/taglib1.git`) as the `builder` user with `makepkg -si --skippgpcheck`. The PKGBUILD `arch` array is patched to add `aarch64`. This is the only AUR dependency.
- **CMake configure flags**
  - The workflow uses the same feature flags as the local integration build, with a few packaging-conscious differences.
  - Notable flags: `QT6=ON`, `QML=ON`, `BULK=ON`, `FFMPEG=ON`, `MAD=ON`, `MODPLUG=OFF`, `OPENMPT=ON`, `WAVPACK=ON`, `BATTERY=ON`, `BROADCAST=ON`, `HID=ON`, `KEYFINDER=ON`, `LILV=ON`, `OPUS=ON`, `QTKEYCHAIN=ON`, `VINYLCONTROL=ON`, `INSTALL_USER_UDEV_RULES=OFF` (no root udev install in the container), `WARNINGS_FATAL=OFF`, `DEBUG_ASSERTIONS_FATAL=OFF`, `CMAKE_BUILD_TYPE=RelWithDebInfo`, ccache launchers on C/C++.
- **ccache**
  - Cache path `/ccache`, 5 GB cap, `hash_dir=false`.
  - Keyed `ccache-manjaro-${{ github.sha }}` with `restore-keys: ccache-manjaro-` for fallback. Saved on every run (`if: always()`).
- **Test step**
  - `ctest --timeout 45 --parallel $(nproc)` with the same flaky test exclusion regex used locally: 
- **Package construction**
  - 1. `cmake --install` into a staging dir (`DESTDIR=$GITHUB_WORKSPACE/staging`), then `chmod -R a+rX` so the `builder` user can read it for `makepkg`.
  - 2. A `PKGBUILD` is generated dynamically:
   - `pkgname=mixxx-milkiib-integrated-manjaro`
   - `pkgver=${MIXXX_VERSION}_${PKGVER_TIMESTAMP}_${SHORT_SHA}` (e.g. `2.6_20260809_1430_abc1234`)
   - `pkgrel=1`, `arch=('x86_64')`, `license=('GPL2')`, `url=https://mixxx.org`
   - `conflicts=('mixxx' 'mixxx-git')`, `provides=('mixxx')` — installing it replaces a stock `mixxx`/`mixxx-git` package.
   - `options=('!strip' '!emptydirs')` — keeps debug symbols (matches `RelWithDebInfo`) and avoids empty-dir warnings.
   - `depends=(...)` is computed at build time by running `ldd` on the staged `mixxx` binary, mapping each shared lib to its owning pacman package via `pacman -Qo`, stripping version constraints, and excluding `gcc`/`glibc`. This keeps the dependency list accurate to what the binary actually links against on Manjaro.
   - `package()` simply `cp -a`s the staged `usr/local/` tree into `${pkgdir}/usr/`.
  - 3. `makepkg -f --noconfirm --skippgpcheck` runs as `builder`. On failure, the PKGBUILD and staging dir listing are printed for debugging before the step exits non-zero.
  - 4. The produced `*.pkg.tar.zst` is uploaded as a workflow artifact (`manjaro-package`, `archive: false`) and attached to a GitHub Release.
- **Release**
  - Action: `softprops/action-gh-release@v2`.
  - Tag: `mixxx-milkiib-integrated-${timestamp}-${short_sha}` (timestamp `YYYYMMDD-HHMM` UTC).
  - Name: `Mixxx MilkiiB Integrated Manjaro Build ${major.minor}-${short_sha}` (major.minor extracted from `project(mixxx VERSION ...)` in `CMakeLists.txt`).
  - `prerelease: true`, `draft: false`.
  - Release body includes install instructions: `sudo pacman -U <pkg>` and a one-liner `curl ... | sudo pacman -U` that pulls the asset directly from the release URL.
  - Notes the build is unsigned, built on Manjaro, compatible with Manjaro and Arch derivatives, with deps resolved by pacman.
- **Operational notes**
  - Every `--promote-integrated` triggers a full Manjaro package build (~10–20 min depending on ccache hit rate).
  - The workflow does NOT block `integrated` promotion; it runs asynchronously after the push. Check status with `gh run list --workflow manjaro-release.yml --repo mxmilkiib/mixxx --limit 3`.
  - Releases accumulate as pre-releases. Prune old ones with `gh release delete <tag> --repo mxmilkiib/mixxx` (and `git push origin :refs/tags/<tag>` to drop the tag) when they are no longer needed — the workflow does not auto-prune.
  - The `builder` user creation is guarded by `id builder >/dev/null 2>&1 || useradd ...` so re-runs within a cached container layer do not fail.
  - `git config --global --add safe.directory "$GITHUB_WORKSPACE"` is required because `actions/checkout` inside a container runs as root but the checkout is owned by a different UID, triggering git's dubious-ownership check.
  - `git fetch origin --force --tags` ensures `git describe --always --first-parent` produces a meaningful version string for the release tag/body.


## Worktree Branch Hygiene

- **Upstream-resolved cleanup**: If an upstream commit (by any contributor) fully resolves the problem a local branch was addressing — rendering the local branch redundant or superseded — the branch entry MUST also be moved to the "Merged to Upstream" section and marked **RESOLVED** (not MERGED), with a note identifying the upstream commit or PR that resolved it. The worktree MUST then be pruned per the **Worktree pruning** rule.

- **Upstream verification before closing**: Before closing or marking a PR/branch as RESOLVED, the fix MUST be verified by reading the actual code in `upstream/main` and `upstream/2.5` — `git show upstream/main:path/to/file.cpp | grep -A N "function"`. A verbal claim that the fix is upstream is NOT sufficient. If verification fails, do not close the PR.

- **Worktree pruning**: When a branch is merged upstream, closed, or abandoned, its worktree MUST be removed (`git worktree remove ~/src/mixxx-dev/<name>`) and the local branch ref MAY be deleted. 
  - This keeps `mixxx-dev/` lean and prevents `mixxx-milkii-integration-update-branches.sh` from wasting time on dead branches.
  - **Merged cleanup**: Once the PR is fully merged into `mixxxdj/mixxx`, the branch entry MUST be moved to the "Merged to Upstream" section of the outline and its `[x]` marker removed, so it is excluded from future integration rebuilds.



## Dev Helper Scripts

| Script | Purpose |
|---|---|
| `mixxx-milkii-integration-update-branches.sh` | Rebase all worktrees (no push), remerge integration (`--remerge-integration` — reset to upstream/main, merge all `INTEGRATION_BRANCHES`, skip if clean, rerere preserves conflict resolutions), configure+build test binaries (parallel configure, serial build, `nice 15`), run test suite with per-branch sentinels for selective re-runs (commit-count + dirty-tree detection), patch-id smart-diff push (`--push-changed` — base-independent, only real content changes trigger CI), push `integrating`, poll GA CI with per-job status (`--promote-integrated`), end-to-end pipeline (`--rebase-merge-test-push-promote` — rebase+merge+build+test+push+CI poll+promote in one command), grand summary |
| `mixxx-milkii-integration-pre-push.sh` | Pre-push hook logic (versioned); `.git/hooks/pre-push` delegates here; runs clang-format check + test suite, blocks local-only files from reaching `mixxxdj/mixxx` |
| `mixxx-milkii-integration-gdb-run.sh` | Launch Mixxx under GDB with `--developer --controller-debug --debug-assert-break`; auto-detects the `mixxx` binary; logs to timestamped file, discards on clean exit; sets `debuginfod enabled`, suppresses `SIG32`/`SIGPIPE`/`SIGUSR*` |


---


## Outline Format Reference
This section documents the structure of this file for AI assistants and future maintainers.


### Summary Line
Update the summary line when adding/removing branches. Every branch is counted exactly once, in the
section it appears in — do not count a schema-excluded branch again under review-required:
```markdown
**Summary** (verified YYYY-MM-DD; each branch counted once): A changes-addressed · B review-required · C changes-requested-open · D schema-excluded · E personal-only/local-only/abandoned/archived · F secondary patches · G merged/resolved upstream · H untracked WIP worktree


### Section Order
1. 🔴 Awaiting Review from Others — a reviewer owes us a response and no change request is outstanding
2. 🟠 Changes Addressed — Awaiting Re-review — we answered a change request; GitHub may still report CHANGES_REQUESTED until re-review
3. 🔧 Secondary Patches
4. 🐛 Bug Fixes — Open PRs
5. 🟡 New Features — Open PRs
6. ⚠️ Schema-Changing Branches (Excluded from Integration)
7. 🔵 Local Only (No PR)
8. ✅ Merged to Upstream / Archived

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

- `[x]` = merged to integration, `[ ]` = not merged
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

```
utf8-string-controls (PERSONAL_ONLY)
├── hotcue-labelling (PERSONAL_ONLY)
└── hotcue-label-options (PERSONAL_ONLY)
```

Branches with dependencies on personal-only branches cannot be submitted upstream as-is. They MUST be refactored to remove the dependency or the dependency MUST be upstreamed first.


## Branch and Integration Status Outline

**Summary** (verified 2026-08-20; each branch counted once): 7 changes-addressed · 7 review-required · 1 changes-requested-open · 2 schema-excluded · 7 personal-only/local-only/abandoned/archived · 2 secondary patches · 10 merged/resolved upstream · 1 untracked WIP worktree

- 🔴 **Awaiting Review from Others**
  - none
- 🟠 **Changes Addressed — Awaiting Re-review**
  - [x] **feature/restore-last-library-selection** - [#15460](https://github.com/mixxxdj/mixxx/pull/15460) - CHANGES_ADDRESSED
    - Worktree: `~/src/mixxx-dev/2025.10oct.20-restore-last-library-selection/` (dir is dated, branch ref is not — branch matches the PR head, so pushes land correctly)
    - Issue: [#10125](https://github.com/mixxxdj/mixxx/issues/10125) (OPEN)
    - Created: 2025-10-08, Last comment: 2026-08-08 (mxmilkiib), Last review: 2025-11-17 (ronso0, CHANGES_REQUESTED), Rebased: 2026-08-08, Updated: 2026-08-08
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
    - Created: 2025-11-16, Last comment: 2026-02-09 (mxmilkiib), Last review: 2026-05-15 (ronso0, CHANGES_REQUESTED), Rebased: 2026-08-08, Updated: 2026-08-03
    - Next: Await re-review — ronso0 CHANGES_REQUESTED (2026-05-15) recorded as addressed 2026-05-26, but no comment or push is visible on the PR after 2026-02-09 and `reviewDecision` is still CHANGES_REQUESTED — UNVERIFIED, confirm before treating as addressed; CI failures are pre-existing flaky (Flatpak aarch64 network timeout, macOS x64 BeatsTranslateTest SEGFAULT — unrelated to our changes)
    - Specifics:
      - daschuer (Feb 9): "this feature already exists" (pref option) — clarified: pref has no CO for runtime control
      - ronso0 confirmed: if it's about changing marker pos on the fly, the pref option has no CO
      - Adds `[Waveform],PlayMarkerPosition` ControlPotmeter (0.0–1.0) for runtime control
    - Tested?: no
  - [x] **feature/2025.11nov.04-controller-wizard-quick-access** - [#15577](https://github.com/mixxxdj/mixxx/pull/15577) - CHANGES_ADDRESSED
    - Issue: [#12262](https://github.com/mixxxdj/mixxx/issues/12262) (OPEN)
    - Created: 2025-11-04, Last comment: 2026-02-18 (mxmilkiib), Last review: 2025-11-16 (ronso0, CHANGES_REQUESTED), Rebased: 2026-08-08, Updated: 2026-08-03
    - Note: rebased with wmainmenubar.cpp/h conflict resolved (Controller+KeyboardEventFilter both included)
    - Next: Awaiting re-review — ronso0 CHANGES_REQUESTED (Nov 16) addressed Feb 18; fix-learning-wizard folded in Feb 22 (ffc28f8)
    - Specifics:
      - ~~devicesChanged not updating menu post-startup~~ fixed — connected to mappingApplied
      - ~~range-for style on m_controllerPages~~ done
      - fix-learning-wizard folded in: emit mappingStarted() before show() so prefs dialog hides before wizard appears
    - Tested?: yes
  - [x] **feature/2025.11nov.05-hide-unenabled-controllers** - [#15580](https://github.com/mixxxdj/mixxx/pull/15580) - CHANGES_ADDRESSED
    - Issue: [#14275](https://github.com/mixxxdj/mixxx/issues/14275) (OPEN)
    - Created: 2025-11-05, Last comment: 2026-08-03 (mxmilkiib), Last review: 2025-11-17 (ronso0, COMMENTED), Rebased: 2026-08-08, Updated: 2026-08-03
    - Next: Awaiting re-review — ronso0 Nov 17 feedback addressed Feb 28: removed redundant null checks, confirmed rename already done; GitHub `reviewDecision` is REVIEW_REQUIRED (no outstanding change request)
    - Specifics:
      - ~~Rename "unenabled" to "disabled" everywhere — config keys, function names, and UI text (ronso0)~~ done
      - ~~Remove unnecessary null checks on tree items — always valid post-construction (ronso0)~~ done
    - Tested?: yes
  - [x] **feature/2026.02feb.26-waveform-menu-order** - [#16046](https://github.com/mixxxdj/mixxx/pull/16046) - CHANGES_ADDRESSED
    - Created: 2026-02-26, Last comment: none (no issue comments), Last review: 2026-05-26 (daschuer, CHANGES_REQUESTED), Rebased: 2026-08-08, Updated: 2026-08-03
    - Next: Await re-review — addressed daschuer: removed lambda + alphabetical sort; order now set via `kValues` in `waveformwidgettype.h`
    - Specifics:
      - Reorders `kValues` in `WaveformWidgetType`: Simple, Filtered, HSV, RGB, Stacked, VSyncTest
      - Removes alphabetical combobox sort from `DlgPrefWaveform` — factory order is display order
      - Old: Simple, Filtered, HSV, VSyncTest, RGB, Stacked → New: Simple, Filtered, HSV, RGB, Stacked, VSyncTest
    - Tested?: yes (1203 tests pass)
  - [x] **feature/2025.10oct.21-stacked-overview-waveform** - [#15516](https://github.com/mixxxdj/mixxx/pull/15516) - DRAFT - CHANGES_ADDRESSED
    - **PR head MISMATCH**: PR head is `feature/stacked-overview-waveform` (fork, last commit 2025-10-21, 1 commit). Local work is on `feature/2025.10oct.21-stacked-overview-waveform` (3 commits, rebased 2026-08-08) and the two patches DIFFER. The PR has been showing ten-month-old code; `--push-changed` cannot fix this because it pushes the dated ref.
    - Issue: [#13265](https://github.com/mixxxdj/mixxx/issues/13265) (OPEN)
    - Created: 2025-10-21, Last comment: 2026-02-17 (mxmilkiib), Last review: 2025-11-01 (mxmilkiib, COMMENTED), Rebased: 2026-08-08 (local ref only), Updated: 2026-02-18
    - Next: Repoint the PR head — push the dated branch to `origin/feature/stacked-overview-waveform` after reviewing the diff, or close and reopen from the current ref. Then re-request review to unstale; no new reviewer feedback since the naming comment (Feb 17).
    - Specifics:
      - ~~Remove redundant Stacked HSV and Stacked LMH renderers~~ done
      - ~~Remove unnecessary static_cast<int>~~ done
      - ~~Rename "Stacked (RGB)" to "Stacked"~~ done
      - All feedback addressed
      - Left comment 2026-02-17 re: Filtered/Stacked naming confusion — see #15996
    - Tested?: yes
  - [ ] **bugfix/2026.02feb.19-wayland-opengl-resize-warning** - [#16014](https://github.com/mixxxdj/mixxx/pull/16014) - CHANGES_ADDRESSED
    - Issue: [#16013](https://github.com/mixxxdj/mixxx/issues/16013) (CLOSED 2026-02-21 as completed — the PR still adds the warning, but the issue no longer justifies it; check whether the PR is still wanted), related [#13814](https://github.com/mixxxdj/mixxx/issues/13814) (OPEN), [#14492](https://github.com/mixxxdj/mixxx/issues/14492) (OPEN)
    - Created: 2026-02-19, Last comment: 2026-08-03 (daschuer), Rebased: 2026-08-03, Updated: 2026-08-03
    - Base: `upstream/2.6`, currently 18 commits behind it (6 ahead) — needs a 2.6 rebase, and `SKIP_BRANCHES` correctly excludes it from the main-based rebase pass
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
    - Created: 2026-05-01, Rebased: 2026-08-08
    - No PR (upstream or fork) exists — the "Next" below has been outstanding since 2026-05-01
    - coTimerId ControlPotmeter max=50 clamped QTimer IDs (10000+ in full suite); replaced with ControlObject
    - Next: open upstream PR to mixxxdj/mixxx
    - Workaround: pre-push hook and script filter `ControllerScriptEngineLegacyTimerTest.*` (entire suite — `beginTimer_repeatedTimer` corrupts clamped-ID-50 state, causing `MidiMappings` JS tests to hang; filtering only `singleShot*` is insufficient) and `TrackMetadataExportTest.keepWithespaceKey` (`getKeyText()` returns `B_FLAT_MINOR` internal string instead of `B♭m` display format, fails in all worktrees). Remove filters once upstream fix lands.
  - [x] **bugfix/2026.02feb.21-hid-init-race-on-enumeration**
    - Created: 2026-02-21, Rebased: 2026-08-08, Updated: 2026-08-05
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
    - Created: 2026-02-19, Last comment: 2026-05-21 (stale-bot), Last review: none, Rebased: 2026-08-03, Updated: 2026-08-20
    - Next: Await review
    - Specifics:
      - Improved: defer FBO reallocation to paintGL via m_pendingResize flag
    - Tested?: yes
  - [x] **bugfix/2026.02feb.19-openglwindow-resize-repaint** - [#16012](https://github.com/mixxxdj/mixxx/pull/16012) - DRAFT - REVIEW_REQUIRED
    - Worktree: `~/src/mixxx-dev/2026.02feb.19-openglwindow-resize-repaint/` (created 2026-08-20)
    - Created: 2026-02-19, Last comment: 2026-05-21 (stale-bot), Last review: none, Rebased: 2026-08-03, Updated: 2026-08-20
    - Next: Await review
    - Specifics:
      - Restores m_dirty flag: defers extra paintGL+swapBuffers from resizeGL to next vsync
      - Does not fix Wayland resize lag (compositor-level issue)
    - Tested?: yes
- 🟡 **NEW FEATURES - Open PRs (REVIEW_REQUIRED)**
  - [x] **feature/2025.11nov.05-deere-waveform-zoom-deck-colors** - [#16874](https://github.com/mixxxdj/mixxx/pull/16874) - REVIEW_REQUIRED
    - Created: 2025-11-05, Rebased: 2026-08-10, Updated: 2026-08-10
    - Next: Await review
    - Specifics:
      - Sets WaveformZoomContainer background to DeckBackgroundColor (was hardcoded #333333)
      - Changes zoom button icon fills from #d2d2d2 to #000000 for visibility on deck-colored background
      - Removes hardcoded background-color from style.qss (now set via XML BgColor)
      - Deere-only change, 5 files, 4 insertions / 4 deletions
    - Tested?: yes (2026-08-10)
  - [x] **feature/2026.05may.03-extend-waveform-zoom-range** — No PR yet
    - Created: 2026-05-03, Rebased: 2026-08-08, Updated: 2026-05-03
    - Next: Test, then open upstream PR
    - Specifics:
      - Extends `s_waveformMinZoom` from 1.0 → 0.5 (allows 200% zoom-in, twice as detailed)
      - Extends `s_waveformMaxZoom` from 10.0 → 80.0 (allows 1.25% zoom-out, 8× more overview)
      - Fixes `DlgPrefWaveform` combo box to handle sub-1.0 zoom entries without integer cast div-by-zero
      - Index↔zoom mapping generalised via `subOneCount` offset
    - Tested?: no
  - [x] **feature/2026.02feb.20-simple-waveform-top-and-overview** - [#16021](https://github.com/mixxxdj/mixxx/pull/16021) - CHANGES_REQUESTED
    - Issue: [#16020](https://github.com/mixxxdj/mixxx/issues/16020) (OPEN)
    - Created: 2026-02-20, Last comment: 2026-05-28 (mxmilkiib, stale-bot reset), Last review: 2026-05-29 (daschuer, CHANGES_REQUESTED), Rebased: 2026-08-08, Updated: 2026-08-03
    - Next: Address daschuer upgrade-path issue — RGB selected before update becomes Simple after; default should remain RGB; likely combobox position stored instead of enum value
    - Specifics:
      - Adds Simple as an overview waveform type (amplitude envelope, signal color, stereo mirrored)
      - Moves Simple to top of overview waveform combobox
      - daschuer CHANGES_REQUESTED: upgrade path alters waveform selection — RGB becomes Simple after update
      - ninomp inline: unused StackedRGB enum entry — mxmilkiib confirmed cruft from branch overlap
    - Tested?: yes (2026-07-16)
  - [x] **feature/2025.10oct.21-replace-libmodplug-with-libopenmpt** - [#15519](https://github.com/mixxxdj/mixxx/pull/15519) - DRAFT - REVIEW_REQUIRED
    - **PR head MISMATCH**: PR head is `feature/replace-libmodplug-with-libopenmpt` (fork, last commit 2025-10-25, 1 commit). Local work is 5 commits on the dated ref and the patches DIFFER — the Feb 2026 `taglibStringToEnumFileType` test fix listed below has never reached the PR.
    - Issue: [#9862](https://github.com/mixxxdj/mixxx/issues/9862) (OPEN)
    - Created: 2025-10-25, Last comment: 2026-02-21 (stale-bot), Last review: 2025-11-22 (gbraad, COMMENTED), Rebased: 2026-08-08 (local ref only), Updated: 2026-02-21
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
    - **PR head MISMATCH**: PR head is `feature/hotcues-on-overview-waveform` (fork, last commit 2025-10-20). Patch content is identical to the dated local ref, so nothing is missing — but the PR base is ten months old, which is why it keeps going stale.
    - Issue: [#14994](https://github.com/mixxxdj/mixxx/issues/14994) (OPEN)
    - Created: 2025-10-20, Last comment: 2026-01-19 (stale-bot), Last review: 2025-10-20 (ronso0, COMMENTED), Rebased: 2026-08-08 (local ref only), Updated: 2026-01-19
    - Next: Repoint the PR head to the dated ref, which also rebases it; await review
    - Specifics:
      - PR marked stale (Jan 19 2026) — needs activity to unstale
      - Paint hotcues on scaled image (option b) not full-width — scaling happens in OverviewCache so fixed pixel widths don't translate
      - Remove `// MARK:` comments
      - Get cue data from delegate columns instead of SQL queries (done)
      - Review feedback from ronso0 on marker rendering approach
    - Tested?: no
  - [x] **feature/2025.11nov.17-deere-channel-mute-buttons** - [#15624](https://github.com/mixxxdj/mixxx/pull/15624) - DRAFT - REVIEW_REQUIRED
    - Issue: [#15623](https://github.com/mixxxdj/mixxx/issues/15623) (OPEN)
    - Created: 2025-11-17, Last comment: 2026-02-23 (ronso0), Last review: none, Rebased: 2026-08-08, Updated: 2026-08-03
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
- ⚠️ **Schema-Changing Branches (Excluded from Integration)**
  - [ ] **feature/2025.10oct.17-library-column-hotcue-count** - [#15462](https://github.com/mixxxdj/mixxx/pull/15462) - REVIEW_REQUIRED
    - **PR head MISMATCH**: PR head is `feature/library-column-hotcue-count` (fork, last commit 2025-10-17, 1 commit). Local ref has 2 commits and the patches DIFFER — the cross-thread SQLite crash fix noted below is NOT on the PR.
    - Issue: [#15461](https://github.com/mixxxdj/mixxx/issues/15461) (CLOSED 2025-11-16 as DUPLICATE — the driving issue is gone; decide whether the PR still has a home before spending more on it)
    - Created: 2025-10-17, Last comment: 2026-01-17 (stale-bot), Last review: none, Rebased: 2026-08-08 (local ref only), Updated: 2026-01-17
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
    - Created: 2025-11-16, Last comment: none (no issue comments), Last review: 2026-02-15 (mxmilkiib, COMMENTED), Rebased: 2026-08-08, Updated: 2026-08-03
    - Next: Await review
    - Specifics:
      - acolombier left review comment 2026-02-14; replied 2026-02-15
      - Schema migration revision 40 — will conflict with hotcue-count branch (also schema change)
      - Removed from integration: schema change; keeping integration at upstream schema v40 until schema branches are stable
      - Uses MusicBrainz Picard tag mapping conventions
    - Tested?: no
- 🔵 **Local Only (No PR)**
  - [ ] **feature/2026.08aug.08-waveform-invert-zoom-direction** — LOCAL_ONLY — **UNCOMMITTED, UNPUSHED**
    - Created: 2026-08-08, Rebased: n/a, Updated: 2026-08-08
    - Worktree exists with 4 modified files (42 insertions / 12 deletions across `dlgprefwaveform.cpp/.h`, `dlgprefwaveformdlg.ui`, `wwaveformviewer.cpp`) and ZERO commits — the branch ref is identical to `main`
    - No `origin` branch — violates the **Local-only backup** rule; a lost `.git` loses this work outright
    - Next: Commit the WIP, push to `origin` for backup, and give it a real outline entry — or discard it deliberately
  - [ ] **feature/2026.02feb.17-mono-waveform-option** — **SKIP_BRANCHES (build-broken)**
    - Created: 2026-02-17, Rebased: 2026-08-03, Updated: 2026-02-17
    - Test binary: [build-fail 2026-05-13]
    - Next: Fix base class — add `MonoSignal` to `WaveformRendererSignalBase::Option` enum and store `m_options` as protected member; both were expected by the branch but never committed or were lost in rebase
    - Specifics:
      - `waveformrendererfiltered.cpp` and `waveformrendererhsv.cpp` reference `m_options` (line 89/90) and `Option::MonoSignal` — neither declared anywhere in the current base class
      - Base class `WaveformRendererSignalBase` Option enum only has: `None`, `SplitStereoSignal`, `HighDetail`, `AllOptionsCombined`
      - Fix: add `MonoSignal = 0b100` to Option enum, store `m_options` in protected block, handle in both .cpp files
  - [x] **feature/2025.10oct.14-waveform-hotcue-label-options**
    - Created: 2025-10-14, Rebased: 2026-08-08, Updated: 2026-01-30
    - Next: Maintain for personal use
  - [x] **feature/2025.10oct.08-utf8-string-controls**
    - Dependency for: hotcue-labelling, hotcue-label-options
    - Created: 2025-10-08, Rebased: 2026-08-08, Updated: 2026-01-30
    - Next: Maintain for personal use (not for upstream)
  - [x] **feature/2025.09sep.25-hotcue-labelling**
    - Created: 2025-09-25, Rebased: 2026-08-08, Updated: 2026-02-20
    - Next: Maintain for personal use
  - [ ] **draft/2025.10oct.21-tracker-module-stems** — ARCHIVED
    - Created: 2025-10-21, Rebased: 2026-08-03, Updated: 2026-08-10, Archived: 2026-08-10
    - Test binary: [build-fail 2026-05-13]
    - Next: Archived — `openmpt::module::set_channel_mute_status` is absent from the stable C++ API (verified against libopenmpt 0.8.6); no alternative mute/channel-render method found. Depends on replace-libmodplug-with-libopenmpt (#15519) being accepted first. Worktree removed.
  - [ ] **feature/2025.02feb.17-waveform-blend-customization** — LOCAL_ONLY — not in integration (branch name year typo: should be 2026)
    - Created: 2026-02-17, Rebased: 2026-08-08 (empty — no commits), Updated: unknown
    - Note: branch ref is identical to `main` (zero commits). The work is four untracked paths in the worktree: `res/shaders/rgbstackedsignal.frag`, `res/shaders/spectrogram.frag`, `src/waveform/analysis/`, plus a stray copy of `INTEGRATION.md` that MUST NOT be committed here
    - `origin/feature/2025.02feb.17-waveform-blend-customization` is just an old `upstream/main` tip, not a backup of anything
    - Sentinel now writes `nocommits` (no commits ahead of upstream) — Gate 2 treats as non-blocking, no longer a false `pass`
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


## TODO Summary

This section is only the short list of things that are actively wrong or actively waiting on Milkii.
Detailed per-branch status lives in the outline above and is not repeated here, aside from the branch name and a brief description of the state. 

- **Blocking, system-level**
  - 4 PRs point at fork branches that are not the ones being developed (#15516, #15519, #15514, #15462)
- **Waiting on reviewers** — 7 changes-addressed PRs; nothing to do but re-request review on the stale ones
- **Waiting on Milkii**
  - #16021 simple-waveform — daschuer's upgrade path issue is the only unaddressed change request
  - #15519 libopenmpt — architecture rework (DSP out of SoundSource, into an effect)
  - extend-waveform-zoom-range and fix-timer-test-potmeter-clamping have no PR at all
  - #15624 deere-channel-mute-buttons is on hold pending a broader plan, not pending code
- **CI status** — run #31330828588 on `origin/integrating` (5996796cd1), completed 2026-08-09: 16 jobs,
  sole failure `build / macOS 15 x64` (BeatsTranslateTest SEGFAULT, matches `KNOWN_INFRA_FAILURES`).
  `auto-promote.yml` had never fired because it was pushed to `integrated` (out-of-band) on 2026-08-10,
  after the last CI run on `integrating` completed — no `workflow_run` event occurred since the workflow
  file existed. Fix applied 2026-08-20: pushed `integration` (containing `auto-promote.yml`) to
  `origin/integrating`, which both restores the invariant (`integrated` ancestor-or-equal of `integrating`)
  and triggers a fresh CI run; auto-promote should fire when CI completes if only known infra failures remain.
- **Architecture changes needed:** replace-libmodplug-with-libopenmpt (daschuer: DSP to effect rack)
- **Archived:** tracker-module-stems (libopenmpt API gap, worktree removed 2026-08-10)
- **Secondary patches:** hid-init-race-on-enumeration (#16838 — REVIEW_REQUIRED, opened 2026-08-04), fix-timer-test-potmeter-clamping (no PR yet)
