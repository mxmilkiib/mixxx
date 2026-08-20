#!/bin/bash

# Mixxx Integration Branch Helper
# Manages worktree rebases, test binary rebuilds, test runs, and branch pushes.
# MUST be committed to the integration branch — see INTEGRATION.md.
# Gist: https://gist.github.com/mxmilkiib/5fb35c401736efed47ad7d78268c80b6
#
# Usage:
#   ./mixxx-milkii-integration-update-branches.sh                            rebase all worktrees (no push)
#   ./mixxx-milkii-integration-update-branches.sh --rebuild-tests            detect and rebuild stale test binaries only (serial)
#   ./mixxx-milkii-integration-update-branches.sh --build-all-tests          configure cmake + build ALL non-skipped branches (serial)
#   ./mixxx-milkii-integration-update-branches.sh --run-tests                run mixxx-test suite; skips branches with valid per-branch sentinel
#   ./mixxx-milkii-integration-update-branches.sh --remerge-integration      reset integration to upstream/main, merge all INTEGRATION_BRANCHES (skip if clean)
#   ./mixxx-milkii-integration-update-branches.sh --push-changed             push only PR branches whose patch content changed (patch-id smart-diff)
#   ./mixxx-milkii-integration-update-branches.sh --push-integrating         promote integration → integrating (requires all worktrees tested)
#   ./mixxx-milkii-integration-update-branches.sh --promote-integrated       promote integrating → integrated (requires GA CI green or known-infra-only failures)
#   ./mixxx-milkii-integration-update-branches.sh --rebase-merge-test-push   rebase + rebuild-integration + build-all-tests + run-tests + push-integration + push-integrating
#   ./mixxx-milkii-integration-update-branches.sh --rebase-merge-test-push-promote  --rebase-merge-test-push + poll GA CI + promote to integrated (end-to-end)
#
# Three-branch promotion chain:
#   integration  — working merges; script operates here; may fail
#   integrating  — locally tested clean; ALL worktrees must have test binaries and pass
#   integrated   — GA CI confirmed clean on origin/integrating; safe to build from
#
# ccache cross-worktree sharing:
#   Each worktree has a different path, so preprocessor #line markers embed different absolute paths,
#   making cache keys differ between worktrees even for identical source files.
#   Fix: pass CCACHE_BASEDIR=<worktree-root> to each build — ccache strips that prefix from all paths
#   in the hash, normalising them to relative paths. Identical source files in different worktrees
#   then produce the same hash and share cache entries.
#   Config: ~/.config/ccache/ccache.conf sets hash_dir=false (CWD not in hash) and max_size=15G.
#
# Skip list:
#   SKIP_BRANCHES lists bare worktree directory names (no path) for branches that have been merged
#   upstream, closed, or abandoned. Their directories may still exist but are ignored by all modes.
#   LOCAL_ONLY and schema-excluded branches are NOT in this list — they still get rebased and tested.
#   They are excluded from integration merges via the [ ] vs [x] markers in INTEGRATION.md (manual step).
#
# Killing a running build:
#   Ctrl-C in the running terminal sends SIGINT to the script's process group, which the trap handles.
#   From another shell: kill -TERM -$(pgrep -fo 'mixxx-milkii-integration-update-branches.sh' | head -1)
#   Do NOT use pkill on cmake/ninja alone — child cc1plus processes will survive and saturate the CPU.
#
# Related files (all committed to integration branch, all synced to gist 5fb35c4):
#   mixxx-milkii-integration-update-branches.sh  — this script
#   mixxx-milkii-integration-pre-push.sh         — hook logic (versioned); .git/hooks/pre-push delegates here
#   mixxx-milkii-integration-gdb-run.sh          — GDB launcher with logging
#   INTEGRATION.md                        — branch registry, process rules, status outline
#
# Runtime state files (not committed):
#   ~/.cache/mixxx-integration/<name>.tested  — per-branch test sentinel: "<HEAD-SHA> <status>"
#                                               status: pass|fail|nocommits|dirty-pass|dirty-fail
#                                               run_tests_serial skips branches whose SHA + "pass" matches current HEAD
#   ~/.cache/mixxx-integration/tests-passed   — global sentinel written when ALL branches pass
#   /tmp/mixxx-integration-status             — append-only progress log; `tail -f` this in a second terminal
#   /tmp/mixxx-test-logs/<name>.log           — per-branch gtest output from the most recent test run

set -euo pipefail

# ── dependency check ───────────────────────────────────────────────────────────
# Two tiers: required tools abort immediately with a list of what is missing;
# optional tools emit a warning to stderr but allow the run to continue.
# Called unconditionally at startup, before any other work.
check_deps() {
    local missing=() warn=()
    local required=(git cmake ninja ldd timeout nice nproc awk free du cut)
    local optional_map=(
        "ccache:ccache is required for cross-worktree cache sharing (cmake configures it)"
        "jq:jq is required for --promote-integrated (GA CI polling)"
        "sensors:sensors (lm-sensors) is optional — omitted from sys_stats CPU temp"
        "tqdm:tqdm is optional — progress bars during builds fall back to plain output"
    )
    for cmd in "${required[@]}"; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    for entry in "${optional_map[@]}"; do
        local cmd="${entry%%:*}" msg="${entry#*:}"
        command -v "$cmd" >/dev/null 2>&1 || warn+=("  WARN: $msg")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "ABORT: missing required dependencies: ${missing[*]}" >&2
        printf '  install: %s\n' "${missing[@]}" >&2
        exit 1
    fi
    for w in "${warn[@]}"; do echo "$w" >&2; done
}
check_deps

# git rerere (reuse recorded resolution) is scoped to remerge_integration ONLY.
# rerere records conflict resolutions during integration merges and auto-replays
# them when the same conflict recurs — essential for remerge_integration() which
# rebuilds the integration branch from scratch.
#
# Rerere is NOT enabled globally because all worktrees share one .git/config.
# If left on, rerere could fire during a feature branch `git rebase upstream/main`
# and auto-apply an integration-merge resolution that combines content from
# multiple branches — polluting the feature branch with unrelated changes that
# could reach an upstream PR.
#
# Instead: remerge_integration() enables rerere before merging and disables it
# after. The recorded resolutions persist in .git/rr-cache/ for the next remerge.
# autoupdate = true: auto-stages resolved files so the merge can continue without
# manual `git add` after rerere fires.
GIT_PAGER=cat git config rerere.enabled false
GIT_PAGER=cat git config rerere.autoupdate true

MIXXX_DEV="${HOME}/src/mixxx-dev"
# MIXXX_MAIN: the integration worktree where the script, INTEGRATION.md and
# helper scripts live and where git operations on the promotion branches run.
# ~/src/mixxx/ is checked out on 'main' (synced with upstream main);
# ~/src/mixxx-dev/integration/ is on 'integration' (all [x] branches merged,
# daily-driver binary built here).
MIXXX_MAIN="${HOME}/src/mixxx-dev/integration"
# BUILD_JOBS: leaves 2 threads unallocated. BUILD_NICE lowers compiler priority so
# interactive processes immediately preempt — more effective than core-count alone.
BUILD_JOBS=$(( $(nproc) - 2 )); [[ $BUILD_JOBS -lt 1 ]] && BUILD_JOBS=1
BUILD_NICE=15
TEST_LOG_DIR="/tmp/mixxx-test-logs"
CACHE_DIR="${HOME}/.cache/mixxx-integration"

# Known upstream test failures filtered in both run_tests_serial and the pre-push hook.
# Keep in sync with KNOWN_FAILING in mixxx-milkii-integration-pre-push.sh.
# Remove entries once the upstream fix is merged into mixxxdj/mixxx main.
#   ControllerScriptEngineLegacyTest.*: softTakeover_setParameter hangs indefinitely in
#     headless environments (no JS controller engine audio output); the entire suite is
#     filtered because softTakeover tests also leave corrupted ControlObject state.
#   ControllerScriptEngineLegacyTimerTest.*: coTimerId ControlPotmeter max=50 clamped QTimer IDs;
#     ALL timer tests filtered (not just singleShot*) because beginTimer_repeatedTimer leaves
#     corrupted ID-50 state that causes downstream MidiMappings JS tests to hang indefinitely.
#   AdjustReplayGainTest.AdjustReplayGainUpdatesPregain: consistent segfault (core dump)
#     in headless environments; likely missing audio engine dependencies.
#   keepWithespaceKey: getKeyText() returns internal enum string instead of display format
#   MidiMappings/.*: HidMappings/.*: BulkMappings/.*: LoadMapping parameterised tests load
#     every bundled controller mapping XML and initialise the JS engine per fixture. Even
#     with ControllerScriptEngineLegacy* filtered, some mappings leave poisoned ControlObject
#     or timer state that causes later MappingTestFixture instances to hang indefinitely
#     (observed: Pioneer_CDJ_350_Ch2_midi_xml). All three mapping suites are filtered
#     because they share the same fixture lifecycle and poisoning pathway.
KNOWN_FAILING='ControllerScriptEngineLegacyTest.*:ControllerScriptEngineLegacyTimerTest.*:AdjustReplayGainTest.AdjustReplayGainUpdatesPregain:TrackMetadataExportTest.keepWithespaceKey:MidiMappings/.*:HidMappings/.*:BulkMappings/.*'

_TQDM=$(command -v tqdm 2>/dev/null || true)
_HAS_TTY=false; [[ -t 1 ]] && _HAS_TTY=true
_PROG_IDX=0; _PROG_TOTAL=0; _PROG_NAME=""

# ── terminal colours ───────────────────────────────────────────────────────
# _C_* always set — used in STATUS_FILE writes so tail -f shows colour.
# _P_* used for stdout: equal to _C_* when running in a TTY, empty otherwise.
_C_RED='\033[0;31m'; _C_GRN='\033[0;32m'; _C_YLW='\033[1;33m'
_C_BLU='\033[0;34m'; _C_CYN='\033[0;36m'; _C_MAG='\033[0;35m'
_C_BLD='\033[1m';    _C_DIM='\033[2m';    _C_NC='\033[0m'
_P_RED=''; _P_GRN=''; _P_YLW=''; _P_BLU=''
_P_CYN=''; _P_MAG=''; _P_BLD=''; _P_DIM=''; _P_NC=''
if $_HAS_TTY; then
    _P_RED="$_C_RED"; _P_GRN="$_C_GRN"; _P_YLW="$_C_YLW"; _P_BLU="$_C_BLU"
    _P_CYN="$_C_CYN"; _P_MAG="$_C_MAG"; _P_BLD="$_C_BLD"; _P_DIM="$_C_DIM"
    _P_NC="$_C_NC"
fi

# ── timing + summary accumulators ──────────────────────────────────────────
_T_SCRIPT_START=$(date +%s)
_T_REBASE_START=0; _T_REBASE_END=0
_T_BUILD_START=0;  _T_BUILD_END=0
_T_TEST_START=0;   _T_TEST_END=0
_REBASE_N_OK=0; _REBASE_N_SKIP=0; _REBASE_N_FAIL=0
_BUILD_RESULTS=()   # "name:secs:ok|fail"
_TEST_RESULTS=()    # "name:secs:pass|fail|skip"

# Status file: `tail -f $STATUS_FILE` in a separate terminal shows real-time progress
# without the noise of thousands of test lines. Updated at each phase/branch transition.
STATUS_FILE="/tmp/mixxx-integration-status"
SENTINEL_FILE="${CACHE_DIR}/tests-passed"
mkdir -p "$CACHE_DIR" "$TEST_LOG_DIR"
# Timestamped status line: colour-codes by keyword (PHASE/DONE/PASS/FAIL/WARN).
# Stdout uses _P_* codes (TTY-conditional); STATUS_FILE always gets _C_* codes so
# `tail -f $STATUS_FILE` shows colour in any terminal that renders ANSI sequences.
status() {
    local msg="[$(date '+%H:%M:%S')] $*" pc="" fc=""
    case "$*" in
        *PHASE*)                              pc="${_P_CYN}${_P_BLD}"; fc="${_C_CYN}${_C_BLD}" ;;
        *DONE*|*" OK"*)                       pc="${_P_GRN}${_P_BLD}"; fc="${_C_GRN}${_C_BLD}" ;;
        *PASS*|*" ok"*|*"OK:"*)              pc="${_P_GRN}";           fc="${_C_GRN}"           ;;
        *FAIL*|*BLOCKED*|*ABORT*|*TIMEOUT*)  pc="${_P_RED}";           fc="${_C_RED}"           ;;
        *WARN*)                               pc="${_P_YLW}";           fc="${_C_YLW}"           ;;
    esac
    printf '%b\n' "${pc}${msg}${_P_NC}"
    printf '%b\n' "${fc}${msg}${_C_NC}" >> "$STATUS_FILE"
}

# Snapshot of system load, memory, and CPU package temperature (if lm-sensors present).
# Called every 5 tests in run_tests_serial and once in print_grand_summary.
sys_stats() {
    local load mem temp=""
    load=$(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null || echo "?")
    mem=$(free -h 2>/dev/null | awk '/^Mem:/{print $3"/"$2}' || echo "?")
    if command -v sensors >/dev/null 2>&1; then
        local t; t=$(sensors 2>/dev/null | grep -oP '(?<=Package id 0:  \+)\S+' | head -1 || true)
        [[ -n "$t" ]] && temp="  ${_C_YLW}CPU ${t}${_C_NC}"
    fi
    printf '%b\n' "  ${_C_DIM}sys: load ${load} | mem ${mem}${temp}${_C_NC}"
}

# Prints an ETA estimate based on elapsed time / completed items, projected linearly.
# Called after each completed build or test. Suppressed when done >= total.
eta_line() {
    local done=$1 total=$2 elapsed=$3 label=$4
    [[ $done -le 0 || $total -le $done ]] && return 0
    local avg=$(( elapsed / done )) rem
    rem=$(( avg * (total - done) ))
    printf '%b\n' "  ${_C_DIM}[ETA ~$(printf '%dm%02ds' $(( rem/60 )) $(( rem%60 ))) | ${done}/${total} done | avg ${avg}s/${label}]${_C_NC}"
}

echo "=== $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$STATUS_FILE"

# ── skip list ──────────────────────────────────────────────────────────────────
# Worktrees for branches that are merged upstream, closed, or abandoned.
# Update when pruning worktrees. Do NOT add LOCAL_ONLY or schema-excluded branches here —
# those are still rebased/tested; they're excluded from integration merges via INTEGRATION.md markers.
SKIP_BRANCHES=(
    "2025.05may.14-fivefourths"
    "2025.06jun.08-deere-deck-bg-colour"
    "2025.11nov.04-reloop-shift-jog-seek"
    "2025.11nov.05-waveform-cache-size-format"
    "2025.11nov.16-reloop-beatmix-mk2-naming"
    "2026.02feb.19-wglwidget-xcb-resize-gap"
    "2026.02feb.20-controlpickermenu-quickfx-deck-offset"
    "2026.02feb.20-fix-learning-wizard-from-prefs-button"
    "2026.02feb.18-midi-makeinputhandler-null-engine"
    "2026.02feb.21-experimental-overview-waveforms"
    # build-broken: openmpt::module::set_channel_mute_status absent from libopenmpt stable API
    "2025.10oct.21-tracker-module-stems"
    # build-broken: m_options member + Option::MonoSignal missing from WaveformRendererSignalBase —
    # base class modifications were not committed or lost in rebase
    "2026.02feb.17-mono-waveform-option"
    # retargeted to upstream/2.6 per maintainer request (#16014) — rebasing onto main would clobber the 2.6 base
    "2026.02feb.19-wayland-opengl-resize-warning"
)

# ── integration merge list ─────────────────────────────────────────────────────
# Ordered list of branch ref names merged into `integration` by remerge_integration().
# This MUST match the [x]-marked branches in INTEGRATION.md — verify before each run.
# Order matters: branches touching the same files (e.g. waveform renderers, dlgprefwaveform)
# MUST be merged in dependency order. The alphabetical-by-date-prefix order below is
# correct for the known overlaps — see "Merge Order for Overlapping Source Files" in
# INTEGRATION.md. Update this list when branches are added to or removed from integration.
INTEGRATION_BRANCHES=(
    "feature/2025.09sep.25-hotcue-labelling"
    "feature/2025.10oct.08-utf8-string-controls"
    "feature/2025.10oct.14-waveform-hotcue-label-options"
    "feature/2025.10oct.20-hotcues-on-overview-waveform"
    "feature/restore-last-library-selection"
    "feature/2025.10oct.21-replace-libmodplug-with-libopenmpt"
    "feature/2025.10oct.21-stacked-overview-waveform"
    "feature/2025.11nov.04-controller-wizard-quick-access"
    "feature/2025.11nov.05-deere-waveform-zoom-deck-colors"
    "feature/2025.11nov.05-hide-unenabled-controllers"
    "feature/2025.11nov.16-playback-position-control"
    "feature/2025.11nov.17-deere-channel-mute-buttons"
    "bugfix/2026.02feb.19-openglwindow-resize-repaint"
    "bugfix/2026.02feb.19-textured-waveform-fbo-resize"
    "feature/2026.02feb.20-simple-waveform-top-and-overview"
    "bugfix/2026.02feb.21-hid-init-race-on-enumeration"
    "feature/2026.02feb.26-waveform-menu-order"
    "bugfix/2026.05may.01-fix-timer-test-potmeter-clamping"
    "feature/2026.05may.03-extend-waveform-zoom-range"
)

# GA CI jobs known to fail for infrastructure/flaky reasons unrelated to code.
# promote_integrated() will still promote integrating → integrated when every
# failed job matches a pattern in this list.  Patterns are bash glob(7) patterns
# matched against the job "name" field from `gh run view --json jobs`.
# Add new patterns here only after confirming a failure is infra/flaky, not code.
KNOWN_INFRA_FAILURES=(
    "build / Flatpak (*"          # xvfb-run exit 1 inside flatpak-builder sandbox
    "build / Windows *VS* *x64"   # dependency checksum mismatch on Windows runners
    "build / Windows *VS* *ARM64" # AdjustReplayGainTest SEGFAULT (same as KNOWN_FAILING locally)
    "build / macOS * x64"         # BeatsTranslateTest SEGFAULT (flaky, pre-existing)
)

# ── helpers ────────────────────────────────────────────────────────────────────

is_skipped() {
    local n="$1"
    for s in "${SKIP_BRANCHES[@]}"; do [[ "$n" == "$s" ]] && return 0; done
    return 1
}

# Returns 0 (true) if the GA CI job name matches a known infra/flaky pattern.
is_known_infra_failure() {
    local job_name="$1"
    for pat in "${KNOWN_INFRA_FAILURES[@]}"; do
        # shellcheck disable=SC2053
        [[ "$job_name" == $pat ]] && return 0
    done
    return 1
}

has_build() { [[ -d "$1/build" && -f "$1/build/CMakeCache.txt" ]]; }
has_test_bin() { [[ -f "$1/build/mixxx-test" ]]; }

is_test_binary_stale() {
    local bin="$1/build/mixxx-test"
    [[ -f "$bin" ]] && ldd "$bin" 2>/dev/null | grep -q "not found"
}

# Returns 0 if the test binary predates the current HEAD commit — the branch was
# rebased or amended after the binary was last linked, so it needs a rebuild.
is_test_binary_older_than_head() {
    local bin="$1/build/mixxx-test"
    [[ -f "$bin" ]] || return 1
    local head_ct bin_mt
    head_ct=$(GIT_PAGER=cat git -C "$1" log -1 --format=%ct 2>/dev/null || echo 0)
    bin_mt=$(stat -c %Y "$bin")
    (( head_ct > bin_mt ))
}

# Returns 0 (true) if the worktree has at least one commit ahead of upstream/main.
# Commitless branches (uncommitted WIP, or branch identical to upstream) get a
# "nocommits" sentinel instead of "pass" — prevents false gate-2 pass.
has_commits_ahead() {
    local count
    count=$(GIT_PAGER=cat git -C "$1" log --oneline upstream/main..HEAD 2>/dev/null | wc -l)
    (( count > 0 ))
}

# Returns 0 (true) if the worktree has uncommitted changes (staged or unstaged).
# A dirty tree means the test binary may include uncommitted source, so the
# sentinel is marked dirty-pass/dirty-fail and always re-tested on next run.
is_dirty_tree() {
    ! GIT_PAGER=cat git -C "$1" diff --quiet 2>/dev/null || \
    ! GIT_PAGER=cat git -C "$1" diff --cached --quiet 2>/dev/null
}

ensure_ccache_enabled() {
    local build_dir="$1/build"
    [[ -f "$build_dir/CMakeCache.txt" ]] || return 0
    if grep -q "CCACHE_SUPPORT:BOOL=OFF" "$build_dir/CMakeCache.txt"; then
        echo "  enabling ccache for $(basename "$1")"
        cmake -DCCACHE_SUPPORT=ON "$build_dir" > /dev/null 2>&1
    fi
}

kill_trap() { printf "\n"; echo "Interrupted — killing build/test processes"; kill 0; exit 130; }

# ── progress display ───────────────────────────────────────────────────────────
# TTY: two-row in-place (row 1 = overall [N/M], row 2 = cmake [XX%]).
# non-TTY + tqdm: line-count progress bar piped through tqdm.
# fallback: plain echo.

progress_start() {
    _PROG_IDX="$1"; _PROG_TOTAL="$2"; _PROG_NAME="$3"
    if $_HAS_TTY; then
        printf "\r\033[K[%d/%d] %s\n\033[K" "$1" "$2" "$3"
    else
        echo "[$1/$2] $3"
    fi
}

_progress_cmake_line() {
    $_HAS_TTY || return 0
    local pct
    pct=$(printf '%s' "$1" | grep -oP '(?<=\[)\s*\d+(?=%\])' | tr -d ' ')
    [[ -z "$pct" ]] && return 0
    printf "\033[1A\033[K[%d/%d] %s\n\033[K%3d%%: %s" \
        "$_PROG_IDX" "$_PROG_TOTAL" "$_PROG_NAME" "$pct" "$1"
}

build_with_progress() {
    # build_with_progress <dir> <target> <idx> <total>
    # Sets CCACHE_BASEDIR=$dir so ccache normalises all absolute paths under the worktree root
    # to relative paths in its hash — enabling cross-worktree cache sharing for unchanged files.
    local dir="$1" target="$2"
    progress_start "$3" "$4" "$(basename "$dir")"
    if $_HAS_TTY; then
        CCACHE_BASEDIR="$dir" nice -n "$BUILD_NICE" cmake --build "$dir/build" --target "$target" \
            -- -j"${BUILD_JOBS}" 2>&1 | \
            while IFS= read -r line; do _progress_cmake_line "$line"; done
        return "${PIPESTATUS[0]}"
    elif [[ -n "$_TQDM" ]]; then
        CCACHE_BASEDIR="$dir" nice -n "$BUILD_NICE" cmake --build "$dir/build" --target "$target" \
            -- -j"${BUILD_JOBS}" 2>&1 | \
            "$_TQDM" --desc "$(basename "$dir")" --unit " lines" > /dev/null
        return "${PIPESTATUS[0]}"
    else
        CCACHE_BASEDIR="$dir" nice -n "$BUILD_NICE" cmake --build "$dir/build" --target "$target" \
            -- -j"${BUILD_JOBS}"
    fi
}

# ── mode: rebase_all ──────────────────────────────────────────────────────────
# Default mode (no argument). Fetches upstream/main, then rebases every non-skipped
# worktree in MIXXX_DEV on upstream/main and force-pushes to origin if a remote exists.
# Skipped branches (SKIP_BRANCHES) are listed but otherwise untouched.
# Does NOT rebuild or retest — run --rebase-merge-test-push or --build-all-tests separately.

rebase_all() {
    _T_REBASE_START=$(date +%s)
    status "PHASE rebase_all — fetching upstream"
    # Ensure rerere is disabled during feature branch rebases — an integration
    # merge resolution must never auto-apply to a feature branch (could pollute
    # a PR with another branch's content). remerge_integration() enables it
    # only for the duration of the integration merge loop.
    GIT_PAGER=cat git config rerere.enabled false
    GIT_PAGER=cat git -C "$MIXXX_MAIN" fetch upstream

    local failed=() skipped=() succeeded=()

    for dir in "${MIXXX_DEV}"/*/; do
        [[ -d "$dir" ]] || continue
        local name; name=$(basename "$dir")
        # skip promotion-chain branches (integration/integrating/integrated) — no YYYY. prefix
        [[ "$name" =~ ^[0-9]{4}\. ]] || continue
        if is_skipped "$name"; then
            skipped+=("$name")
            echo "--- Skipping $name (merged/closed/abandoned)"
            continue
        fi
        status "rebase: $name"
        if GIT_PAGER=cat git -C "$dir" rebase upstream/main; then
            status "  $name — rebased"
            succeeded+=("$name")
        else
            status "  FAILED $name — aborting rebase"
            GIT_PAGER=cat git -C "$dir" rebase --abort 2>/dev/null || true
            failed+=("$name")
        fi
    done

    echo ""
    _T_REBASE_END=$(date +%s)
    _REBASE_N_OK=${#succeeded[@]}; _REBASE_N_SKIP=${#skipped[@]}; _REBASE_N_FAIL=${#failed[@]}
    status "DONE rebase_all: ${#succeeded[@]} ok  ${#skipped[@]} skipped  ${#failed[@]} failed"
    if [[ ${#failed[@]} -gt 0 ]]; then
        echo "Failed branches:"; printf '  - %s\n' "${failed[@]}"; return 1
    fi
}

# ── mode: remerge_integration ──────────────────────────────────────────────────
# Remerges the integration branch: resets to upstream/main, then merges each branch
# in INTEGRATION_BRANCHES in order with `git merge --no-edit`.
# Skip-when-clean: if upstream/main is an ancestor of integration AND all
# INTEGRATION_BRANCHES are ancestors, the remerge is skipped (integration is current).
# On conflict: if git rerere has staged a resolution and no unmerged paths remain,
# the merge is committed automatically (rerere-resolved). Only conflicts with
# genuinely unresolved paths abort the remerge with a CONFLICT message.
# git rerere (enabled in repo config) records conflict resolutions — after resolving
# a conflict once manually, subsequent remerges auto-resolve the same conflict.
# Infrastructure preservation: files that exist only on the integration branch
# (workflows, helper scripts, INTEGRATION.md) are saved from the pre-reset HEAD and
# restored after all merges complete — git reset --hard upstream/main would otherwise
# destroy them and break the promotion chain.
# Schema-excluded and [ ]-marked branches are NOT in INTEGRATION_BRANCHES.

remerge_integration() {
    # Ensure MIXXX_MAIN is on the integration branch
    local current_branch
    current_branch=$(GIT_PAGER=cat git -C "$MIXXX_MAIN" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    if [[ "$current_branch" != "integration" ]]; then
        status "ABORT remerge_integration: MIXXX_MAIN is on '$current_branch', not 'integration'"
        return 1
    fi

    # Ensure upstream/main is current
    GIT_PAGER=cat git -C "$MIXXX_MAIN" fetch upstream 2>/dev/null || true

    # Skip-when-clean: if upstream/main is an ancestor of integration AND all
    # INTEGRATION_BRANCHES are ancestors, integration is current — skip the remerge.
    # Note: if a branch was REMOVED from INTEGRATION_BRANCHES, this check will still
    # pass (the removed branch is still an ancestor). To force a remerge after removing
    # a branch, reset integration first: git -C $MIXXX_MAIN reset --hard upstream/main
    local all_ancestors=true
    GIT_PAGER=cat git -C "$MIXXX_MAIN" merge-base --is-ancestor upstream/main integration 2>/dev/null || all_ancestors=false
    if $all_ancestors; then
        for branch in "${INTEGRATION_BRANCHES[@]}"; do
            GIT_PAGER=cat git -C "$MIXXX_MAIN" merge-base --is-ancestor "$branch" integration 2>/dev/null || { all_ancestors=false; break; }
        done
    fi
    if $all_ancestors; then
        status "SKIP remerge_integration: integration is current (upstream/main + all ${#INTEGRATION_BRANCHES[@]} branches are ancestors)"
        return 0
    fi

    status "PHASE remerge_integration — resetting integration to upstream/main, merging ${#INTEGRATION_BRANCHES[@]} branches"

    # Record pre-reset SHA so infrastructure files that live only on the
    # integration branch (not in upstream/main or any feature branch) can be
    # restored after the remerge.  Without this, git reset --hard upstream/main
    # destroys auto-promote.yml, manjaro-release.yml, the helper scripts, and
    # INTEGRATION.md — breaking the promotion chain on the next push.
    local pre_reset_sha
    pre_reset_sha=$(GIT_PAGER=cat git -C "$MIXXX_MAIN" rev-parse HEAD)

    # Enable rerere only for the duration of this remerge.
    # See the comment at the top of the script for why rerere is not globally enabled.
    GIT_PAGER=cat git config rerere.enabled true

    # Reset integration to upstream/main (clean slate)
    GIT_PAGER=cat git -C "$MIXXX_MAIN" reset --hard upstream/main
    status "  integration reset to upstream/main $(GIT_PAGER=cat git -C "$MIXXX_MAIN" rev-parse --short upstream/main)"

    # Merge each branch in order
    # git rerere (enabled in repo config) will auto-resolve known conflicts:
    #   - "Resolved '<file>' using previous resolution." = rerere replayed a known resolution
    #   - "Recorded resolution for '<file>'." = rerere recorded a new resolution (first time)
    local merged=() conflicts=() idx=0
    for branch in "${INTEGRATION_BRANCHES[@]}"; do
        (( idx++ )) || true
        status "  merge [$idx/${#INTEGRATION_BRANCHES[@]}] $branch"
        if GIT_PAGER=cat git -C "$MIXXX_MAIN" merge --no-edit "$branch" 2>&1; then
            status "  OK: $branch"
            merged+=("$branch")
        else
            # git merge exits non-zero even when rerere has staged a resolution.
            # Check whether any conflicts remain unresolved; if rerere handled
            # them all, commit and continue instead of aborting.
            local unresolved
            unresolved=$(GIT_PAGER=cat git -C "$MIXXX_MAIN" diff --name-only --diff-filter=U 2>/dev/null)
            if [[ -z "$unresolved" ]]; then
                GIT_EDITOR=true git -C "$MIXXX_MAIN" commit --no-edit 2>/dev/null
                status "  OK (rerere): $branch"
                merged+=("$branch")
            else
                # Real unresolved conflicts — abort and report immediately
                GIT_PAGER=cat git -C "$MIXXX_MAIN" merge --abort 2>/dev/null || true
                status "  CONFLICT: $branch — merge aborted, integration has ${#merged[@]} branches so far"
                conflicts+=("$branch")
                break
            fi
        fi
    done

    if [[ ${#conflicts[@]} -gt 0 ]]; then
        echo ""
        status "BLOCKED remerge_integration: ${#conflicts[@]} branch(es) had merge conflicts:"
        printf '  CONFLICT: %s\n' "${conflicts[@]}"
        status "  Already merged cleanly (${#merged[@]}): ${merged[*]}"
        status "  Resolve manually in the integration worktree:"
        status "    cd $MIXXX_MAIN && git merge --no-edit $branch"
        status "  (rerere is enabled — resolve, git add, git commit to record the resolution)"
        status "  Then re-run: $0 --rebase-merge-test-push"
        status "  Or continue without remerge: $0 --build-all-tests && $0 --run-tests && $0 --push-integrating"
        # Leave rerere enabled so the manual resolution gets recorded.
        # rebase_all() will disable it before rebasing feature branches.
        return 1
    fi

    # Restore infrastructure files that live only on the integration branch.
    # Two categories:
    #   (a) Files that do NOT exist in upstream/main — gone after reset, must be
    #       restored from the pre-reset SHA (auto-promote.yml, manjaro-release.yml,
    #       INTEGRATION.md, the three helper scripts).
    #   (b) Files that DO exist in upstream/main but have integration-specific
    #       modifications — reset replaces them with upstream versions, so the
    #       modifications are silently lost unless we detect the content drift
    #       and restore from the pre-reset SHA (develop.yml, pre-commit.yml).
    local infra_files=(
        ".github/workflows/auto-promote.yml"
        ".github/workflows/develop.yml"
        ".github/workflows/manjaro-release.yml"
        ".github/workflows/pre-commit.yml"
        "INTEGRATION.md"
        "mixxx-milkii-integration-gdb-run.sh"
        "mixxx-milkii-integration-pre-push.sh"
        "mixxx-milkii-integration-update-branches.sh"
    )
    local need_restore=()
    for f in "${infra_files[@]}"; do
        local pre_sha post_sha
        pre_sha=$(GIT_PAGER=cat git -C "$MIXXX_MAIN" rev-parse "$pre_reset_sha:$f" 2>/dev/null || echo "")
        post_sha=$(GIT_PAGER=cat git -C "$MIXXX_MAIN" rev-parse "HEAD:$f" 2>/dev/null || echo "")
        if [[ -z "$post_sha" || "$pre_sha" != "$post_sha" ]]; then
            need_restore+=("$f")
        fi
    done
    if [[ ${#need_restore[@]} -gt 0 ]]; then
        status "  restoring ${#need_restore[@]} infrastructure file(s) from pre-reset integration"
        GIT_PAGER=cat git -C "$MIXXX_MAIN" checkout "$pre_reset_sha" -- "${need_restore[@]}"
        GIT_EDITOR=true git -C "$MIXXX_MAIN" commit -m "restore integration infrastructure after remerge" 2>/dev/null
    fi

    # Disable rerere — feature branch rebases must not auto-apply integration
    # merge resolutions (see the comment at the top of the script).
    GIT_PAGER=cat git config rerere.enabled false

    status "DONE remerge_integration: ${#merged[@]} branches merged cleanly"
}

# ── mode: push_changed_branches ──────────────────────────────────────────────
# Pushes feature/bugfix branches to origin ONLY when their patch content has
# actually changed relative to what is already on origin. A pure rebase (same
# diff, different base commit) is not pushed — avoids wasteful CI runs.
#
# Compares patch-ids of the commit ranges upstream/main..HEAD vs upstream/main..origin/<branch>.
# patch-id computes a hash of each commit's diff content, ignoring the base commit —
# so a pure rebase (same patches, different base) produces identical patch-ids and is skipped.
# This is base-independent, unlike the previous git diff approach which compared against
# a moving upstream/main and falsely reported every branch as changed after an upstream sync.
# If origin/<branch> does not exist, the branch is always pushed (first push).
#
# Push policy categories:
#   PUSH_ALWAYS  — promotion chain (integration, integrating) — handled elsewhere
#   PUSH_ON_CHANGE — all YYYY. worktrees with open PRs (default)
#   PUSH_NEVER   — SKIP_BRANCHES

push_changed_branches() {
    status "PHASE push_changed_branches — smart-diff push (only content changes)"
    # Fetch origin to ensure remote-tracking refs are current
    GIT_PAGER=cat git -C "$MIXXX_MAIN" fetch origin --prune 2>/dev/null || true

    local pushed=() skipped=() no_remote=() failed=()

    for dir in "${MIXXX_DEV}"/*/; do
        [[ -d "$dir" ]] || continue
        local name; name=$(basename "$dir")
        [[ "$name" =~ ^[0-9]{4}\. ]] || continue
        is_skipped "$name" && continue

        local branch_name
        branch_name=$(GIT_PAGER=cat git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
        [[ -z "$branch_name" ]] && continue

        # Check if origin/<branch> exists
        if ! GIT_PAGER=cat git -C "$dir" rev-parse --verify "origin/$branch_name" >/dev/null 2>&1; then
            # First push — always push
            if GIT_PAGER=cat git -C "$dir" push --no-verify --force-with-lease origin HEAD 2>/dev/null; then
                status "  $name — pushed (new remote branch)"
                pushed+=("$name")
            else
                status "  $name — push FAILED"
                failed+=("$name")
            fi
            continue
        fi

        # Compare patch-ids of local vs origin commit ranges — base-independent.
        # patch-id hashes each commit's diff content, ignoring the base commit.
        # A pure rebase produces the same patch-ids as the original commits.
        local local_pids origin_pids
        local_pids=$(GIT_PAGER=cat git -C "$dir" log --no-merges -p upstream/main..HEAD 2>/dev/null | \
            git patch-id --stable 2>/dev/null | awk '{print $1}' | sort)
        origin_pids=$(GIT_PAGER=cat git -C "$dir" log --no-merges -p upstream/main..origin/"$branch_name" 2>/dev/null | \
            git patch-id --stable 2>/dev/null | awk '{print $1}' | sort)

        if [[ "$local_pids" == "$origin_pids" ]]; then
            skipped+=("$name")
            continue
        fi

        # Content differs — push
        if GIT_PAGER=cat git -C "$dir" push --no-verify --force-with-lease origin HEAD 2>/dev/null; then
            status "  $name — pushed (content changed)"
            pushed+=("$name")
        else
            status "  $name — push FAILED"
            failed+=("$name")
        fi
    done

    echo ""
    status "DONE push_changed_branches: ${#pushed[@]} pushed  ${#skipped[@]} skipped (unchanged)  ${#failed[@]} failed"
    if [[ ${#skipped[@]} -gt 0 ]]; then
        printf '%b\n' "  ${_C_DIM}Skipped (pure rebase, no CI value): ${skipped[*]}${_C_NC}"
    fi
    [[ ${#failed[@]} -eq 0 ]] || { printf '  FAILED: %s\n' "${failed[@]}"; return 1; }
}

# ── mode: build_all_tests ─────────────────────────────────────────────────────
# Two-phase: configure then build.
#   Configure (parallel, background): runs cmake -G Ninja for any worktree lacking
#     a build dir, collecting pids and waiting for all to finish before building.
#   Build (serial, nice 15): builds the mixxx-test target for every worktree that
#     either has no binary, has a stale binary (ldd finds missing libs), or was
#     just configured. Serial to avoid saturating memory with parallel link steps.
#     CCACHE_BASEDIR is set per worktree so ccache path-normalisation works across
#     all worktrees — see the ccache section in the header for details.
# After building, ensures ccache is enabled in all build dirs (including MIXXX_MAIN)
# and prints a colourised ccache statistics summary.

build_all_tests() {
    _T_BUILD_START=$(date +%s)
    status "PHASE build_all_tests"
    trap kill_trap INT TERM

    local to_configure=() to_build=() name
    for dir in "${MIXXX_DEV}"/*/; do
        [[ -d "$dir" ]] || continue
        name=$(basename "$dir")
        [[ "$name" =~ ^[0-9]{4}\. ]] || continue
        is_skipped "$name" && continue
        if ! has_build "$dir"; then
            to_configure+=("$dir")
            to_build+=("$dir")
        elif ! has_test_bin "$dir" || is_test_binary_stale "$dir"; then
            to_build+=("$dir")
        elif is_test_binary_older_than_head "$dir"; then
            to_build+=("$dir")
        fi
    done

    if [[ ${#to_configure[@]} -eq 0 && ${#to_build[@]} -eq 0 ]]; then
        status "All test binaries up to date."
        return 0
    fi
    if [[ ${#to_configure[@]} -gt 0 ]]; then
        echo "Unconfigured (${#to_configure[@]}):"
        for dir in "${to_configure[@]}"; do echo "  - $(basename "$dir")"; done
    fi
    if [[ ${#to_build[@]} -gt 0 ]]; then
        echo "Need (re)build (${#to_build[@]}):"
        for dir in "${to_build[@]}"; do echo "  - $(basename "$dir")"; done
    fi
    echo ""

    # cmake configure phase — run all in parallel (configure is I/O-bound, safe to parallelise)
    local configure_failed=() _pids=() _pdirs=()
    for dir in "${to_configure[@]}"; do
        name=$(basename "$dir")
        local cfg_log="$CACHE_DIR/configure-${name}.log"
        local cmake_args=(-S "$dir" -B "$dir/build"
            -DCMAKE_BUILD_TYPE=RelWithDebInfo
            -DCCACHE_SUPPORT=ON)
        command -v ninja > /dev/null 2>&1 && cmake_args+=(-GNinja)
        status "  configure (launch) $name"
        CCACHE_BASEDIR="$dir" cmake "${cmake_args[@]}" > "$cfg_log" 2>&1 &
        _pids+=($!)
        _pdirs+=("$dir")
    done
    echo "  Waiting for ${#_pids[@]} parallel configures..."
    for _i in "${!_pids[@]}"; do
        local _n; _n=$(basename "${_pdirs[$_i]}")
        if wait "${_pids[$_i]}"; then
            status "  configure OK: $_n"
        else
            status "  configure FAILED: $_n  (log: $CACHE_DIR/configure-${_n}.log)"
            configure_failed+=("$_n")
        fi
    done
    if [[ ${#configure_failed[@]} -gt 0 ]]; then
        printf '  configure FAILED: %s\n' "${configure_failed[@]}"; return 1
    fi

    # ensure ccache on all build dirs (newly configured + existing)
    for dir in "${MIXXX_DEV}"/*/; do
        [[ -d "$dir" ]] || continue
        is_skipped "$(basename "$dir")" && continue
        ensure_ccache_enabled "$dir"
    done
    ensure_ccache_enabled "$MIXXX_MAIN"

    # build phase
    printf '%b\n' "Building serially — ${_C_BLD}-j${BUILD_JOBS}${_C_NC}, nice ${BUILD_NICE}, CCACHE_BASEDIR per worktree..."
    local built=() build_failed=() idx=0 _phase_t0; _phase_t0=$(date +%s)
    for dir in "${to_build[@]}"; do
        name=$(basename "$dir")
        (( idx++ )) || true
        local _t0; _t0=$(date +%s)
        local _commits _bsz
        _commits=$(GIT_PAGER=cat git -C "$dir" log --oneline HEAD ^upstream/main 2>/dev/null | wc -l || echo "?")
        _bsz=$(du -sh "$dir/build" 2>/dev/null | cut -f1 || echo "?")
        printf '%b\n' "${_C_BLD}  build [$idx/${#to_build[@]}] ${name}${_C_NC}  ${_C_DIM}(${_commits} commits, build dir: ${_bsz})${_C_NC}"
        if build_with_progress "$dir" mixxx-test "$idx" "${#to_build[@]}"; then
            local _et=$(( $(date +%s) - _t0 ))
            $_HAS_TTY && printf "\n"
            status "  build OK: $name (${_et}s)"; built+=("$name")
            _BUILD_RESULTS+=("${name}:${_et}:ok")
            eta_line "$idx" "${#to_build[@]}" "$(( $(date +%s) - _phase_t0 ))" "build"
        else
            local _et=$(( $(date +%s) - _t0 ))
            $_HAS_TTY && printf "\n"
            status "  build FAILED: $name (${_et}s)"; build_failed+=("$name")
            _BUILD_RESULTS+=("${name}:${_et}:fail")
        fi
    done
    _T_BUILD_END=$(date +%s)

    echo ""; printf '%b\n' "=== Build: ${_C_GRN}${#built[@]} ok${_C_NC}  $([[ ${#build_failed[@]} -gt 0 ]] && printf '%b' "${_C_RED}${#build_failed[@]} failed${_C_NC}" || echo "0 failed") ==="
    [[ ${#build_failed[@]} -eq 0 ]] || { printf '  FAILED: %s\n' "${build_failed[@]}"; return 1; }
    echo ""
    status "ccache summary:"
    ccache -s 2>/dev/null | while IFS= read -r line; do
        case "$line" in
            *"hit"*)           printf '%b\n' "  ${_C_GRN}${line}${_C_NC}" ;;
            *"miss"*)          printf '%b\n' "  ${_C_YLW}${line}${_C_NC}" ;;
            *"size"*|*"files"*) printf '%b\n' "  ${_C_BLD}${line}${_C_NC}" ;;
            *)                 printf '%b\n' "  ${_C_DIM}${line}${_C_NC}" ;;
        esac
    done || printf '%b\n' "  ${_C_DIM}(ccache -s unavailable)${_C_NC}"
}

# ── mode: rebuild_tests_serial ────────────────────────────────────────────────────
# Lighter alternative to --build-all-tests: skips branches with a healthy binary,
# rebuilds only those whose mixxx-test has missing shared libs (ldd "not found").
# Does NOT run cmake configure — use --build-all-tests for branches with no build dir.

rebuild_tests_serial() {
    status "PHASE rebuild_tests_serial"
    trap kill_trap INT TERM

    local stale=() no_build=()
    for dir in "${MIXXX_DEV}"/*/; do
        [[ -d "$dir" ]] || continue
        local name; name=$(basename "$dir")
        is_skipped "$name" && continue
        if ! has_test_bin "$dir"; then
            no_build+=("$name")
        elif is_test_binary_stale "$dir"; then
            stale+=("$name")
        fi
    done

    if [[ ${#no_build[@]} -gt 0 ]]; then
        echo "No test binary — build not configured (these branches are skipped):"
        printf '  - %s\n' "${no_build[@]}"
    fi

    if [[ ${#stale[@]} -eq 0 ]]; then status "All test binaries up to date."; return 0; fi

    echo ""; echo "Stale (${#stale[@]}):"; printf '  - %s\n' "${stale[@]}"; echo ""
    echo "Enabling ccache on affected build dirs..."
    for dir in "${MIXXX_DEV}"/*/; do
        [[ -d "$dir" ]] || continue
        is_skipped "$(basename "$dir")" && continue
        ensure_ccache_enabled "$dir"
    done
    ensure_ccache_enabled "$MIXXX_MAIN"

    echo "Rebuilding serially — -j${BUILD_JOBS}, CCACHE_BASEDIR per worktree for cross-worktree sharing..."
    local rebuilt=() build_failed=() idx=0

    for dir in "${MIXXX_DEV}"/*/; do
        [[ -d "$dir" ]] || continue
        local name; name=$(basename "$dir")
        [[ "$name" =~ ^[0-9]{4}\. ]] || continue
        is_skipped "$name" && continue
        is_test_binary_stale "$dir" || continue
        (( idx++ )) || true
        if build_with_progress "$dir" mixxx-test "$idx" "${#stale[@]}"; then
            $_HAS_TTY && printf "\n"; status "  rebuild done: $name"; rebuilt+=("$name")
        else
            $_HAS_TTY && printf "\n"; status "  rebuild FAILED: $name"; build_failed+=("$name")
        fi
    done

    echo ""; echo "=== Rebuild: ${#rebuilt[@]} ok  ${#build_failed[@]} failed ==="
    [[ ${#build_failed[@]} -eq 0 ]] || { printf '  FAILED: %s\n' "${build_failed[@]}"; return 1; }
}

# ── mode: run_tests_serial ────────────────────────────────────────────────────
# Runs mixxx-test serially across all non-skipped worktrees that have a test binary.
# Selective re-run via per-branch sentinels: if ~/.cache/mixxx-integration/<name>.tested
# contains the current HEAD SHA with status "pass", that branch is skipped entirely.
# A background heartbeat job prints running test count every 30s so the terminal is
# not silent during long-running tests. Tests are filtered by KNOWN_FAILING.
#
# Sentinel format: "<HEAD-SHA> <status>" where status is:
#   pass        — clean tree, has commits ahead of upstream, tests pass
#   fail        — tests failed (regardless of dirty/clean)
#   nocommits   — no commits ahead of upstream/main; nothing to test, not counted as passing
#   dirty-pass  — dirty working tree, tests pass (unreliable — binary may include uncommitted source)
#   dirty-fail  — dirty working tree, tests failed
# Only "pass" causes run_tests_serial to skip a branch on re-run. "dirty-pass" is
# always re-tested because the uncommitted state may have changed.
# On completion, writes/updates the per-branch sentinel and (if all pass) the global
# sentinel at SENTINEL_FILE.

run_tests_serial() {
    _T_TEST_START=$(date +%s)
    trap kill_trap INT TERM
    mkdir -p "$TEST_LOG_DIR" "$CACHE_DIR"

    # Selective: skip branches whose per-branch sentinel matches their current HEAD
    # with status "pass". Commitless branches get "nocommits" and are skipped (nothing
    # to test). Dirty-pass sentinels are always re-tested (uncommitted state may have changed).
    local dirs_with_tests=() skipped_names=() nocommits_names=()
    for dir in "${MIXXX_DEV}"/*/; do
        [[ -d "$dir" ]] || continue
        local name; name=$(basename "$dir")
        [[ "$name" =~ ^[0-9]{4}\. ]] || continue
        is_skipped "$name" && continue
        has_test_bin "$dir" || continue
        local branch_sha; branch_sha=$(GIT_PAGER=cat git -C "$dir" rev-parse HEAD 2>/dev/null || echo unknown)

        # Commitless branches: write nocommits sentinel and skip — nothing to test
        if ! has_commits_ahead "$dir"; then
            printf '%s nocommits\n' "$branch_sha" > "$CACHE_DIR/${name}.tested"
            nocommits_names+=("$name")
            _TEST_RESULTS+=("${name}:0:skip")
            continue
        fi

        local bsentinel="$CACHE_DIR/${name}.tested"
        if [[ -f "$bsentinel" ]]; then
            local s_sha s_status; read -r s_sha s_status < "$bsentinel"
            if [[ "$s_sha" == "$branch_sha" && "$s_status" == "pass" ]]; then
                skipped_names+=("$name")
                _TEST_RESULTS+=("${name}:0:skip")
                continue
            fi
        fi
        dirs_with_tests+=("$dir")
    done

    [[ ${#nocommits_names[@]} -gt 0 ]] && \
        echo "No commits ahead of upstream — skipping ${#nocommits_names[@]}: ${nocommits_names[*]}"
    [[ ${#skipped_names[@]} -gt 0 ]] && \
        echo "Sentinel current — skipping ${#skipped_names[@]}: ${skipped_names[*]}"

    local total=${#dirs_with_tests[@]}
    if [[ $total -eq 0 ]]; then
        status "All worktrees have current passing sentinels — nothing to run"
        return 0
    fi
    status "PHASE run_tests_serial ($total to run, ${#skipped_names[@]} skipped, ${#nocommits_names[@]} nocommits) — upstream failures filtered"
    echo "Logs: $TEST_LOG_DIR"
    echo ""

    local passed=() failed=() idx=0
    for dir in "${dirs_with_tests[@]}"; do
        local name; name=$(basename "$dir")
        (( idx++ )) || true
        local log="$TEST_LOG_DIR/${name}.log"
        local timeout_secs=420
        local t0; t0=$(date +%s)
        local branch_sha; branch_sha=$(GIT_PAGER=cat git -C "$dir" rev-parse HEAD 2>/dev/null || echo unknown)
        local dirty=""; is_dirty_tree "$dir" && dirty="dirty"
        [[ -n "$dirty" ]] && status "  WARN: $name has uncommitted changes — test result may not reflect committed state"
        status "test [$idx/$total] $name  (log: $log)"
        echo "  Monitor: tail -f $log"
        # background heartbeat: print test count every 30s so terminal is not silent
        ( while true; do
              sleep 30
              local c; c=$(grep -ac 'RUN      ' "$log" 2>/dev/null || true)
              local el=$(( $(date +%s) - t0 ))
              status "  ... [$idx/$total] $name — ${c:-?} tests, ${el}s elapsed"
          done ) &
        local _hb_pid=$!
        if (cd "$dir/build" && timeout "$timeout_secs" ./mixxx-test --gtest_filter="-${KNOWN_FAILING}") > "$log" 2>&1; then
            kill "$_hb_pid" 2>/dev/null; wait "$_hb_pid" 2>/dev/null || true
            local elapsed=$(( $(date +%s) - t0 ))
            local s_status="pass"; [[ -n "$dirty" ]] && s_status="dirty-pass"
            status "  ${s_status^^} [$idx/$total] $name (${elapsed}s)"
            passed+=("$name")
            _TEST_RESULTS+=("${name}:${elapsed}:pass")
            printf '%s %s\n' "$branch_sha" "$s_status" > "$CACHE_DIR/${name}.tested"
        else
            local rc=$?
            kill "$_hb_pid" 2>/dev/null; wait "$_hb_pid" 2>/dev/null || true
            local elapsed=$(( $(date +%s) - t0 ))
            local s_status="fail"; [[ -n "$dirty" ]] && s_status="dirty-fail"
            if [[ $rc -eq 124 ]]; then
                status "  TIMEOUT [$idx/$total] $name (exceeded ${timeout_secs}s after ${elapsed}s)"
                status "  Last: $(grep -a 'RUN      ' "$log" | tail -1 || echo unknown)"
            else
                status "  ${s_status^^} [$idx/$total] $name (${elapsed}s, see $log)"
                grep -E "^\[  FAILED  \]" "$log" | grep -v "FAILED\] [0-9]" | head -8 || true
            fi
            _TEST_RESULTS+=("${name}:${elapsed}:fail")
            failed+=("$name")
            printf '%s %s\n' "$branch_sha" "$s_status" > "$CACHE_DIR/${name}.tested"
        fi
        [[ $(( idx % 5 )) -eq 0 ]] && sys_stats
        eta_line "$idx" "$total" "$(( $(date +%s) - _T_TEST_START ))" "test"
    done
    _T_TEST_END=$(date +%s)

    echo ""
    local total_pass=$(( ${#passed[@]} + ${#skipped_names[@]} ))
    status "DONE run_tests_serial: ${#passed[@]} pass  ${#failed[@]} fail  ${#skipped_names[@]} skipped  ${#nocommits_names[@]} nocommits"
    if [[ ${#failed[@]} -eq 0 ]]; then
        local head_sha; head_sha=$(GIT_PAGER=cat git -C "$MIXXX_MAIN" rev-parse HEAD)
        printf '%s %d\n' "$head_sha" "$total_pass" > "$SENTINEL_FILE"
        status "  Global sentinel written ($total_pass branches passing)"
    else
        status "Failed: ${failed[*]}"; return 1
    fi
}

# ── mode: push_integration ────────────────────────────────────────────────────
# Force-pushes the current integration branch to origin/integration.
# Triggers the pre-push hook (style check + main-worktree test run).
# Safe to run at any time — integration is intentionally ephemeral.

push_integration() {
    status "PHASE push_integration"
    GIT_PAGER=cat git -C "$MIXXX_MAIN" push --force-with-lease origin integration
    status "DONE integration branch pushed"
}

# ── mode: push_integrating ────────────────────────────────────────────────────
# Gate 2: promotes integration → integrating only when ALL non-skipped worktrees
# satisfy both:
#   (a) a test binary exists and passes ldd (not stale), AND
#   (b) a per-branch sentinel exists for the current HEAD with an acceptable status.
# Acceptable statuses: "pass" (clean, tested), "nocommits" (no work, non-blocking),
# "dirty-pass" (warns but passes — unreliable but probably OK).
# Blocking statuses: "fail", "dirty-fail", missing sentinel, HEAD moved.
# Pushing integrating triggers GA CI on a clean runner — different from local tests
# which run on the same kernel/libs as the build.

push_integrating() {
    # Gate 1: every non-skipped worktree must have a test binary
    local missing=() current_bins=0
    for dir in "${MIXXX_DEV}"/*/; do
        [[ -d "$dir" ]] || continue
        local name; name=$(basename "$dir")
        [[ "$name" =~ ^[0-9]{4}\. ]] || continue
        is_skipped "$name" && continue
        if has_test_bin "$dir"; then
            (( current_bins++ )) || true
        else
            missing+=("$name")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        status "BLOCKED push_integrating: ${#missing[@]} active branches have no test binary:"
        printf '  - %s\n' "${missing[@]}"
        status "  Run: $0 --build-all-tests  then  $0 --run-tests"
        return 1
    fi
    # Gate 2: every branch must have a per-branch sentinel with an acceptable status
    local need_test=() dirty_warnings=() nocommits_count=0
    for dir in "${MIXXX_DEV}"/*/; do
        [[ -d "$dir" ]] || continue
        local name; name=$(basename "$dir")
        [[ "$name" =~ ^[0-9]{4}\. ]] || continue
        is_skipped "$name" && continue
        has_test_bin "$dir" || continue
        local branch_sha; branch_sha=$(GIT_PAGER=cat git -C "$dir" rev-parse HEAD 2>/dev/null || echo unknown)

        # Commitless branches are non-blocking — no work to fail
        if ! has_commits_ahead "$dir"; then
            (( nocommits_count++ )) || true
            continue
        fi

        local bsentinel="$CACHE_DIR/${name}.tested"
        if [[ ! -f "$bsentinel" ]]; then
            need_test+=("$name (no sentinel)")
        else
            local s_sha s_status; read -r s_sha s_status < "$bsentinel"
            if [[ "$s_sha" != "$branch_sha" ]]; then
                need_test+=("$name (HEAD moved)")
            else
                case "$s_status" in
                    pass)        ;;  # OK
                    nocommits)   (( nocommits_count++ )) || true ;;  # non-blocking
                    dirty-pass)  dirty_warnings+=("$name") ;;  # warn but pass
                    *)           need_test+=("$name (last: $s_status)") ;;  # fail, dirty-fail, etc.
                esac
            fi
        fi
    done
    if [[ ${#need_test[@]} -gt 0 ]]; then
        status "BLOCKED push_integrating: ${#need_test[@]} branches need passing tests:"
        printf '  - %s\n' "${need_test[@]}"
        status "  Run: $0 --run-tests"
        return 1
    fi
    [[ ${#dirty_warnings[@]} -gt 0 ]] && \
        status "  WARN: ${#dirty_warnings[@]} branches tested with dirty tree: ${dirty_warnings[*]}"
    [[ $nocommits_count -gt 0 ]] && \
        status "  INFO: $nocommits_count commitless branches skipped (non-blocking)"
    status "PHASE push_integrating — all $current_bins worktrees built + per-branch tested"
    GIT_PAGER=cat git -C "$MIXXX_MAIN" branch -f integrating HEAD
    GIT_PAGER=cat git -C "$MIXXX_MAIN" push --force-with-lease origin integrating
    status "DONE integrating pushed — GA CI triggered on origin/integrating"
    status "  Monitor: gh run list --branch integrating --repo mxmilkiib/mixxx"
    status "  Promote when green: $0 --promote-integrated"
}

# ── mode: promote_integrated ──────────────────────────────────────────────────
# Polls GA CI on origin/integrating. On success, fast-forwards local+remote
# integrated to match — this is the CI-confirmed-clean gate.
# Reports per-job status on each poll so progress is visible without external polling.

promote_integrated() {
    local _jq; _jq=$(command -v jq 2>/dev/null || true)
    if [[ -z "$_jq" ]]; then
        status "ERROR: jq not found — install jq to use --promote-integrated"
        return 1
    fi
    status "PHASE promote_integrated — polling GA CI on origin/integrating"
    local timeout_secs=3600 poll_interval=60
    local t0; t0=$(date +%s)
    local _prev_jobs=""
    while true; do
        local elapsed=$(( $(date +%s) - t0 ))
        [[ $elapsed -gt $timeout_secs ]] && {
            status "TIMEOUT: CI did not complete within ${timeout_secs}s"; return 1
        }
        local run_json
        run_json=$(gh run list --branch integrating --repo mxmilkiib/mixxx \
            --limit 1 --json databaseId,status,conclusion 2>/dev/null) || {
            status "ERROR: gh run list failed — check: gh auth status"
            return 1
        }
        local run_id run_status conclusion
        run_id=$(    echo "$run_json" | "$_jq" -r '.[0].databaseId // "?"')
        run_status=$(echo "$run_json" | "$_jq" -r '.[0].status     // "unknown"')
        conclusion=$( echo "$run_json" | "$_jq" -r '.[0].conclusion // "null"')
        if [[ "$run_status" == "completed" ]]; then break; fi
        # Fetch per-job status for progress reporting
        local jobs_json _jobs_summary
        jobs_json=$(gh run view "$run_id" --repo mxmilkiib/mixxx \
            --json jobs --jq '[.jobs[] | "\(.status)/\(.conclusion // "")/\(.name)"] | .[]' 2>/dev/null || true)
        _jobs_summary=$(echo "$jobs_json" | sort)
        if [[ "$_jobs_summary" != "$_prev_jobs" ]]; then
            status "  run #$run_id: $run_status (${elapsed}s total)"
            while IFS='/' read -r _jstat _jconc _jname; do
                [[ -z "$_jname" ]] && continue
                local _icon="?"
                if [[ "$_jstat" == "completed" ]]; then
                    case "$_jconc" in
                        success)    _icon="OK" ;;
                        failure)    _icon="FAIL" ;;
                        cancelled)  _icon="CXL" ;;
                        skipped)    _icon="SKIP" ;;
                        *)          _icon="??" ;;
                    esac
                elif [[ "$_jstat" == "in_progress" ]]; then
                    _icon=".."
                elif [[ "$_jstat" == "queued" ]]; then
                    _icon="Q"
                elif [[ "$_jstat" == "waiting" ]]; then
                    _icon="W"
                fi
                status "    [$_icon] $_jname"
            done <<< "$jobs_json"
            _prev_jobs="$_jobs_summary"
        fi
        sleep "$poll_interval"
    done
    status "  run #$run_id: completed — conclusion=$conclusion"
    local _promote=1   # 1 = promote, 0 = block
    if [[ "$conclusion" == "success" ]]; then
        status "  GA CI passed — promoting integrating → integrated"
    else
        # CI failed — check whether every failed job is a known infra/flaky failure.
        # If so, promote anyway; otherwise block.
        local failed_jobs
        failed_jobs=$(gh run view "$run_id" --repo mxmilkiib/mixxx \
            --json jobs --jq '[.jobs[] | select(.conclusion=="failure" or .conclusion=="cancelled") | .name] | .[]' 2>/dev/null)
        local _all_known=1 _unknown=()
        while IFS= read -r _jname; do
            [[ -z "$_jname" ]] && continue
            if is_known_infra_failure "$_jname"; then
                status "  known infra failure: $_jname"
            else
                status "  UNKNOWN failure:     $_jname"
                _all_known=0; _unknown+=("$_jname")
            fi
        done <<< "$failed_jobs"
        if (( _all_known )) && [[ -n "$failed_jobs" ]]; then
            status "  GA CI failed ($conclusion) — all failures are known infra/flaky, promoting"
        else
            status "  GA CI FAILED ($conclusion) — NOT promoting integrated"
            status "  Unknown failures: ${_unknown[*]:-none}"
            status "  View failures: gh run view $run_id --repo mxmilkiib/mixxx"
            return 1
        fi
    fi
    if (( _promote )); then
        # ~/src/mixxx/ is on 'main' — no dedicated integrated worktree exists.
        # Update the local ref from MIXXX_MAIN and force-push to origin.
        local integrating_sha; integrating_sha=$(GIT_PAGER=cat git -C "$MIXXX_MAIN" rev-parse integrating)
        GIT_PAGER=cat git -C "$MIXXX_MAIN" branch -f integrated "$integrating_sha"
        GIT_PAGER=cat git -C "$MIXXX_MAIN" push --no-verify --force-with-lease origin integrated
        status "  origin/integrated → ${integrating_sha}"
        status "DONE integrated pushed — CI-confirmed clean build"
    fi
}

# ── grand summary ──────────────────────────────────────────────────────────────────────────────────
# Reads the phase timing accumulators (_T_*_START/END) and result arrays
# (_BUILD_RESULTS, _TEST_RESULTS) to produce a colourised summary table.
# Reports: total elapsed, per-phase duration + pass/fail/skip counts, slowest
# build and test branch, a sys_stats snapshot, and the final promotion outcome.
# Called automatically at the end of rebase_merge_test_push.

print_grand_summary() {
    local build_ok=$1 integrating_ok=$2
    local t_end; t_end=$(date +%s)
    local total=$(( t_end - _T_SCRIPT_START ))
    local rebase_t=$(( _T_REBASE_END > 0 ? _T_REBASE_END - _T_REBASE_START : 0 ))
    local build_t=$(( _T_BUILD_END  > 0 ? _T_BUILD_END  - _T_BUILD_START  : 0 ))
    local test_t=$(( _T_TEST_END   > 0 ? _T_TEST_END   - _T_TEST_START   : 0 ))
    local b_ok=0 b_fail=0 t_pass=0 t_fail=0 t_skip=0
    local slowest_build="" slow_bt=0 slowest_test="" slow_tt=0
    for e in "${_BUILD_RESULTS[@]+"${_BUILD_RESULTS[@]}"}" ; do
        local _n="${e%%:*}" _r="${e##*:}" _t="${e#*:}"; _t="${_t%%:*}"
        [[ "$_r" == ok ]] && (( b_ok++ )) || (( b_fail++ ))
        [[ $_t -gt $slow_bt ]] && { slowest_build="$_n"; slow_bt=$_t; }
    done
    for e in "${_TEST_RESULTS[@]+"${_TEST_RESULTS[@]}"}" ; do
        local _n="${e%%:*}" _r="${e##*:}" _t="${e#*:}"; _t="${_t%%:*}"
        case "$_r" in pass) (( t_pass++ ));; fail) (( t_fail++ ));; skip) (( t_skip++ ));; esac
        [[ $_t -gt $slow_tt && "$_r" != skip ]] && { slowest_test="$_n"; slow_tt=$_t; }
    done
    local rb_c=$(( _REBASE_N_FAIL > 0 )) bi_c=$(( b_fail > 0 )) ts_c=$(( t_fail > 0 ))
    local SEP="${_C_CYN}${_C_BLD}"; local DIV="${_C_DIM}"; local E="${_C_NC}"
    printf '%b\n' "${SEP}═══════════════════════════════════════════════════${E}"
    printf '%b\n' " ${_C_BLD}GRAND SUMMARY  —  $(date '+%Y-%m-%d %H:%M')${E}"
    printf '%b\n' " Total: ${_C_BLD}$(printf '%dm%02ds' $(( total/60 )) $(( total%60 )))${E}"
    printf '%b\n' "${DIV}───────────────────────────────────────────────────${E}"
    printf '%b\n' " ${DIV}Phase       Dur         Result${E}"
    local rc_r=$( (( rb_c )) && printf '%b' "${_C_RED}" || printf '%b' "${_C_GRN}" )
    local rc_b=$( (( bi_c )) && printf '%b' "${_C_RED}" || printf '%b' "${_C_GRN}" )
    local rc_t=$( (( ts_c )) && printf '%b' "${_C_RED}" || printf '%b' "${_C_GRN}" )
    printf '%b\n' " Rebase     $(printf '%dm%02ds' $(( rebase_t/60 )) $(( rebase_t%60 )))     ${rc_r}${_REBASE_N_OK} ok  ${_REBASE_N_SKIP} skip  ${_REBASE_N_FAIL} fail${E}"
    printf '%b\n' " Build      $(printf '%dm%02ds' $(( build_t/60 )) $(( build_t%60 )))     ${rc_b}${b_ok} ok  ${b_fail} fail${E}"
    printf '%b\n' " Test       $(printf '%dm%02ds' $(( test_t/60 )) $(( test_t%60 )))     ${rc_t}${t_pass} pass  ${t_fail} fail  ${t_skip} skip${E}"
    if [[ -n "$slowest_build" || -n "$slowest_test" ]]; then
        printf '%b\n' "${DIV}───────────────────────────────────────────────────${E}"
        [[ -n "$slowest_build" ]] && printf '%b\n' " Slowest build: ${_C_BLD}${slowest_build}${E}  ${slow_bt}s"
        [[ -n "$slowest_test"  ]] && printf '%b\n' " Slowest test:  ${_C_BLD}${slowest_test}${E}   ${slow_tt}s"
    fi
    printf '%b\n' "${DIV}───────────────────────────────────────────────────${E}"
    sys_stats
    printf '%b\n' "${DIV}───────────────────────────────────────────────────${E}"
    if ! $build_ok; then
        printf '%b\n' " integration  pushed → origin/integration"
        printf '%b\n' " ${_C_RED}integrating  BLOCKED — build failure(s)${E}"
        printf '%b\n' " ${DIV}Fix builds, then: --build-all-tests  --run-tests  --push-integrating${E}"
    elif $integrating_ok; then
        printf '%b\n' " integration  pushed → origin/integration"
        printf '%b\n' " ${_C_GRN}integrating  pushed → origin/integrating${E}"
        printf '%b\n' " ${DIV}GA CI triggered — monitor, then: --promote-integrated${E}"
    else
        printf '%b\n' " integration  pushed → origin/integration"
        printf '%b\n' " ${_C_YLW}integrating  BLOCKED — not all branches tested${E}"
        printf '%b\n' " ${DIV}Once ready: --run-tests  then  --push-integrating${E}"
    fi
    printf '%b\n' "${SEP}═══════════════════════════════════════════════════${E}"
}

# ── mode: rebase_merge_test_push ──────────────────────────────────────────────
# Orchestrates the complete integration pipeline in order:
#   1. rebase_all             — fetch upstream, rebase all worktrees
#   2. remerge_integration    — reset integration to upstream/main, merge all INTEGRATION_BRANCHES (skip if clean)
#   3. build_all_tests        — configure (parallel) + build (serial) all test binaries
#   4. run_tests_serial       — run tests, skip branches with current passing sentinels
#   5. push_integration       — push integration branch to origin
#   6. push_integrating       — promote to integrating if all gates pass (skipped on build failure)
#   7. print_grand_summary    — timing, per-phase results, slowest branch, sys stats
# A merge conflict in step 2 with genuinely unresolved paths is fatal: the script
# stops before build/test/push. If rerere has staged a resolution with no unmerged
# paths, the merge is committed automatically. The AI resolves unresolved conflicts
# manually, then re-runs.
# A build failure is non-fatal: steps 3–4 still run, step 5 is blocked.
# Stopped partway: each phase persists its own state (cmake build dirs, per-branch
# sentinels), so individual modes can be re-run to resume from any point.

rebase_merge_test_push() {
    local ts; ts=$(date '+%Y-%m-%d %H:%M')
    echo "╔══════════════════════════════════════════════╗"
    printf  "║  Rebase+Merge+Test+Push — %-20s║\n" "$ts"
    echo "╚══════════════════════════════════════════════╝"
    echo ""
    echo "Real-time status: tail -f $STATUS_FILE"
    echo "Test logs:        tail -f $TEST_LOG_DIR/<worktree>.log"
    echo ""

    rebase_all           || { echo "ABORT: rebase step had failures."; exit 1; }
    echo ""
    remerge_integration  || { echo "ABORT: integration merge had conflicts — resolve manually, then re-run."; exit 1; }
    echo ""
    local _build_ok=true
    build_all_tests || _build_ok=false
    echo ""
    run_tests_serial     || { echo "ABORT: tests failed — fix before pushing."; exit 1; }
    echo ""
    push_integration
    echo ""
    local _integrating_ok=true
    if ! $_build_ok; then
        status "push_integrating skipped — build failures present (see above)"
        _integrating_ok=false
    else
        push_integrating || _integrating_ok=false
    fi
    echo ""
    print_grand_summary "$_build_ok" "$_integrating_ok"
}

# ── mode: rebase_merge_test_push_promote ──────────────────────────────────────
# Full integration pipeline + GA CI polling + promotion to integrated.
# Chains rebase_merge_test_push() with promote_integrated() so the entire
# integration → integrating → integrated chain runs in one command.
# The AI can launch this as a single background command and poll
# command_status periodically — all progress is reported via status().

rebase_merge_test_push_promote() {
    local ts; ts=$(date '+%Y-%m-%d %H:%M')
    echo "╔══════════════════════════════════════════════╗"
    printf  "║  Rebase+Merge+Test+Push+Promote — %-10s║\n" "$ts"
    echo "╚══════════════════════════════════════════════╝"
    echo ""
    echo "Real-time status: tail -f $STATUS_FILE"
    echo "Test logs:        tail -f $TEST_LOG_DIR/<worktree>.log"
    echo ""

    rebase_all           || { echo "ABORT: rebase step had failures."; exit 1; }
    echo ""
    remerge_integration  || { echo "ABORT: integration merge had conflicts — resolve manually, then re-run."; exit 1; }
    echo ""
    local _build_ok=true
    build_all_tests || _build_ok=false
    echo ""
    run_tests_serial     || { echo "ABORT: tests failed — fix before pushing."; exit 1; }
    echo ""
    push_integration
    echo ""
    local _integrating_ok=true
    if ! $_build_ok; then
        status "push_integrating skipped — build failures present (see above)"
        _integrating_ok=false
    else
        push_integrating || _integrating_ok=false
    fi
    echo ""
    print_grand_summary "$_build_ok" "$_integrating_ok"

    if $_integrating_ok; then
        echo ""
        promote_integrated || {
            status "promote_integrated failed — CI did not pass or timed out"
            status "  Re-run when CI passes: $0 --promote-integrated"
            return 1
        }
    else
        status "SKIPPED promote_integrated — integrating was not pushed"
        return 1
    fi
}

# ── dispatch ───────────────────────────────────────────────────────────────────

case "${1:-}" in
    --rebuild-tests)             rebuild_tests_serial ;;
    --build-all-tests)           build_all_tests ;;
    --run-tests)                 run_tests_serial ;;
    --remerge-integration)       remerge_integration ;;
    --push-changed)              push_changed_branches ;;
    --push-integrating)          push_integrating ;;
    --promote-integrated)        promote_integrated ;;
    --rebase-merge-test-push)    rebase_merge_test_push ;;
    --rebase-merge-test-push-promote) rebase_merge_test_push_promote ;;
    "")                          rebase_all ;;
    *) echo "Usage: $0 [--rebuild-tests | --build-all-tests | --run-tests | --remerge-integration | --push-changed | --push-integrating | --promote-integrated | --rebase-merge-test-push | --rebase-merge-test-push-promote]"; exit 1 ;;
esac
