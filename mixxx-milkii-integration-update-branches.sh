#!/bin/bash

# Mixxx Integration Branch Helper
# Manages worktree rebases, test binary rebuilds, test runs, and branch pushes.
# MUST be committed to the integration branch — see INTEGRATION.md.
# Gist: https://gist.github.com/mxmilkiib/5fb35c401736efed47ad7d78268c80b6
#
# Usage:
#   ./mixxx-milkii-integration-update-branches.sh --validate-manifest
#   ./mixxx-milkii-integration-update-branches.sh                         # rebase manifest-selected worktrees
#   ./mixxx-milkii-integration-update-branches.sh --build-all-tests       # build selected branches + integration
#   ./mixxx-milkii-integration-update-branches.sh --run-tests             # serial exact-build tests
#   ./mixxx-milkii-integration-update-branches.sh --remerge-integration   # transactional clean remerge
#   ./mixxx-milkii-integration-update-branches.sh --remerge-integration --dry-run  # build candidate, do not install
#   ./mixxx-milkii-integration-update-branches.sh --push-changed          # push branches with changed patches
#   ./mixxx-milkii-integration-update-branches.sh --push-integrating      # enforce local gate and trigger CI
#   ./mixxx-milkii-integration-update-branches.sh --promote-integrated    # promote exact successful CI SHA
#   ./mixxx-milkii-integration-update-branches.sh --rebase-merge-test-push
#   ./mixxx-milkii-integration-update-branches.sh --rebase-merge-test-push-promote
#   ./mixxx-milkii-integration-update-branches.sh --quick-integration     # rebase+remerge+build integration only, skip tests and remote
#
# INTEGRATION.md is authoritative for managed worktrees, bases, dependencies,
# merge order, gate membership, test exclusions, workflows, and infrastructure.
#
# Three-branch promotion chain:
#   integration  — transactional combined merge candidate
#   integrating  — exact integration SHA built and tested locally
#   integrated   — the same SHA after strict GitHub Actions success
#
# Runtime state files (not committed):
#   ~/.cache/mixxx-integration/<name>.built   — exact build signature
#   ~/.cache/mixxx-integration/<name>.tested  — build signature plus pass/fail
#   ~/.cache/mixxx-integration/tests-passed   — combined pass summary
#   /tmp/mixxx-integration-status             — progress log
#   /tmp/mixxx-test-logs/<name>.log           — per-tree gtest output

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
MIXXX_MAIN="$SCRIPT_DIR"
MIXXX_DEV="$(dirname "$MIXXX_MAIN")"
INTEGRATION_DOC="$MIXXX_MAIN/INTEGRATION.md"
BUILD_JOBS=$(( $(nproc) - 2 )); [[ $BUILD_JOBS -lt 1 ]] && BUILD_JOBS=1
BUILD_NICE=15
TEST_LOG_DIR="/tmp/mixxx-test-logs"
CACHE_DIR="${HOME}/.cache/mixxx-integration"

check_deps() {
    local missing=() warn=()
    local required=(git gh python3 cmake ninja ccache ldd timeout nice nproc awk free du cut stat sha256sum mktemp)
    local optional_map=(
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

manifest_query() {
    python3 - "$INTEGRATION_DOC" "$@" <<'PY'
import hashlib
import json
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
action = sys.argv[2]
text = path.read_text()
match = re.search(
    r"<!-- MIXXX_INTEGRATION_MANIFEST_START -->\s*```json\s*(.*?)\s*```\s*<!-- MIXXX_INTEGRATION_MANIFEST_END -->",
    text,
    re.DOTALL,
)
if not match:
    raise SystemExit(f"{path}: integration manifest markers not found")
data = json.loads(match.group(1))
defaults = data["branch_defaults"]
branches = [{**defaults, **branch} for branch in data["branches"]]

if action == "validate-json":
    if data.get("schema") != 1:
        raise SystemExit("unsupported integration manifest schema")
    refs = [branch["ref"] for branch in branches]
    worktrees = [branch["worktree"] for branch in branches]
    if len(refs) != len(set(refs)) or len(worktrees) != len(set(worktrees)):
        raise SystemExit("duplicate branch ref or worktree in integration manifest")
    known = set(refs)
    seen = set()
    merge_orders = []
    for branch in branches:
        missing = set(branch["dependencies"]) - known
        if missing:
            raise SystemExit(f"{branch['ref']}: unknown dependencies: {sorted(missing)}")
        unordered = set(branch["dependencies"]) - seen
        if unordered:
            raise SystemExit(f"{branch['ref']}: dependencies must appear first: {sorted(unordered)}")
        for key in ("rebase", "test", "integrate", "gate"):
            if not isinstance(branch[key], bool):
                raise SystemExit(f"{branch['ref']}: {key} must be boolean")
        if branch["integrate"]:
            if not all((branch["rebase"], branch["test"], branch["gate"])):
                raise SystemExit(f"{branch['ref']}: integrated branches must rebase, test, and gate")
            if not isinstance(branch.get("merge_order"), int):
                raise SystemExit(f"{branch['ref']}: merge_order is required")
            merge_orders.append(branch["merge_order"])
        elif branch["gate"]:
            raise SystemExit(f"{branch['ref']}: a gate branch must be integrated")
        seen.add(branch["ref"])
    if len(merge_orders) != len(set(merge_orders)):
        raise SystemExit("duplicate merge_order in integration manifest")
    outline = text.split("## Branch and Integration Status Outline", 1)[1]
    outline = outline.split("## TODO Summary", 1)[0]
    outline_refs = set(re.findall(r"^\s*- \[x\] \*\*([^*]+)\*\*", outline, re.MULTILINE))
    integrated_refs = {branch["ref"] for branch in branches if branch["integrate"]}
    if outline_refs != integrated_refs:
        missing = sorted(integrated_refs - outline_refs)
        extra = sorted(outline_refs - integrated_refs)
        raise SystemExit(f"manifest/outline integration mismatch; missing={missing}, extra={extra}")
    workflow_dir = path.parent / ".github" / "workflows"
    for key in ("ci_workflow", "release_workflow"):
        if not (workflow_dir / data[key]).is_file():
            raise SystemExit(f"manifest {key} does not exist: {data[key]}")
    ci_text = (workflow_dir / data["ci_workflow"]).read_text()
    ci_name_match = re.search(r"^name:\s*['\"]?(.+?)['\"]?\s*$", ci_text, re.MULTILINE)
    if not ci_name_match or ci_name_match.group(1) != data["ci_workflow_name"]:
        raise SystemExit("manifest CI workflow name disagrees with its workflow file")
    for infrastructure_file in data["infrastructure_files"]:
        if not (path.parent / infrastructure_file).is_file():
            raise SystemExit(f"manifest infrastructure file does not exist: {infrastructure_file}")
    auto_promote_files = [
        file for file in data["infrastructure_files"] if file.endswith("integration-auto-promote.yml")
    ]
    if len(auto_promote_files) != 1:
        raise SystemExit("manifest must declare exactly one auto-promote workflow")
    auto_promote_text = (path.parent / auto_promote_files[0]).read_text()
    if f'- "{data["ci_workflow_name"]}"' not in auto_promote_text:
        raise SystemExit("auto-promote trigger disagrees with manifest CI workflow name")
    for name, source in data["package_sources"].items():
        if name == "container":
            if "@sha256:" not in source:
                raise SystemExit("package container must be digest-pinned")
        elif not re.fullmatch(r"[0-9a-f]{40}", source["commit"]):
            raise SystemExit(f"{name}: package source must use a full commit SHA")
    print(f"manifest valid: {len(branches)} worktrees, {len(merge_orders)} integrated branches")
elif action == "branch-records":
    mode = sys.argv[3] if len(sys.argv) > 3 else "all"
    for branch in branches:
        if mode != "all" and not branch[mode]:
            continue
        dependency = branch["dependencies"][0] if branch["dependencies"] else "-"
        pr_head = branch.get("pr_head", "-")
        external = str(branch.get("external", False)).lower()
        fields = (
            branch["ref"],
            branch["worktree"],
            branch["base"],
            str(branch["rebase"]).lower(),
            str(branch["test"]).lower(),
            str(branch["integrate"]).lower(),
            str(branch["gate"]).lower(),
            dependency,
            pr_head,
            external,
        )
        print("\t".join(fields))
elif action == "pr-records":
    for branch in branches:
        if "pr" in branch:
            print(f"{branch['ref']}\t{branch['pr']}\t{branch.get('pr_head', branch['ref'])}")
elif action == "integration-branches":
    for branch in sorted((b for b in branches if b["integrate"]), key=lambda b: b["merge_order"]):
        print(branch["ref"])
elif action == "test-filter":
    print(":".join(data["test_exclusions"]))
elif action == "infrastructure-files":
    print("\n".join(data["infrastructure_files"]))
elif action == "manifest-hash":
    canonical = json.dumps(data, sort_keys=True, separators=(",", ":")).encode()
    print(hashlib.sha256(canonical).hexdigest())
elif action == "get":
    value = data
    for key in sys.argv[3].split("."):
        value = value[key]
    print(value)
else:
    raise SystemExit(f"unknown manifest query: {action}")
PY
}

manifest_query validate-json >/dev/null
KNOWN_FAILING="$(manifest_query test-filter)"
MANIFEST_HASH="$(manifest_query manifest-hash)"
REPOSITORY="$(manifest_query get repository)"
CI_WORKFLOW="$(manifest_query get ci_workflow)"
mapfile -t INTEGRATION_BRANCHES < <(manifest_query integration-branches)
mapfile -t INFRASTRUCTURE_FILES < <(manifest_query infrastructure-files)

env GIT_PAGER=cat git -C "$MIXXX_MAIN" config rerere.enabled false
env GIT_PAGER=cat git -C "$MIXXX_MAIN" config rerere.autoupdate true

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
    local msg pc="" fc=""
    msg="[$(date '+%H:%M:%S')] $*"
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

# ── manifest validation + helpers ─────────────────────────────────────────────

validate_manifest() {
    manifest_query validate-json
    local errors=() ref worktree base _rebase _test _integrate _gate _dependency dir current
    declare -A declared=()
    while IFS=$'\t' read -r ref worktree base _rebase _test _integrate _gate _dependency _pr_head; do
        declared["$worktree"]=1
        dir="$MIXXX_DEV/$worktree"
        if [[ ! -d "$dir" ]]; then
            errors+=("$worktree (declared worktree missing)")
            continue
        fi
        current=$(env GIT_PAGER=cat git -C "$dir" branch --show-current 2>/dev/null || true)
        [[ "$current" == "$ref" ]] || errors+=("$worktree (expected $ref, found ${current:-detached})")
        env GIT_PAGER=cat git -C "$MIXXX_MAIN" rev-parse --verify "$base" >/dev/null 2>&1 || \
            errors+=("$worktree (base $base missing)")
    done < <(manifest_query branch-records all)
    for dir in "$MIXXX_DEV"/[0-9][0-9][0-9][0-9].*/; do
        [[ -d "$dir" ]] || continue
        worktree=$(basename "$dir")
        [[ -n "${declared[$worktree]:-}" ]] || errors+=("$worktree (worktree absent from manifest)")
    done
    # PR head identity check: for branches with a declared PR, verify the PR
    # head ref on GitHub still matches the manifest's pr_head (or ref if no
    # pr_head). Drift means the PR is watching a branch nobody is developing on.
    local pr_ref pr_number pr_head_declared pr_head_remote
    while IFS=$'\t' read -r pr_ref pr_number pr_head_declared; do
        pr_head_remote=$(gh pr view "$pr_number" --repo mixxxdj/mixxx \
            --json headRefName --jq '.headRefName' 2>/dev/null || true)
        if [[ -z "$pr_head_remote" ]]; then
            errors+=("$pr_ref (PR #$pr_number not found or gh query failed)")
        elif [[ "$pr_head_remote" != "$pr_head_declared" ]]; then
            errors+=("$pr_ref (PR #$pr_number head is '$pr_head_remote', manifest declares '$pr_head_declared')")
        fi
    done < <(manifest_query pr-records)
    if [[ ${#errors[@]} -gt 0 ]]; then
        status "ABORT manifest/worktree validation failed:"
        printf '  - %s\n' "${errors[@]}"
        return 1
    fi
    status "OK manifest and ${#declared[@]} managed worktrees agree"
}

has_build() { [[ -d "$1/build" && -f "$1/build/CMakeCache.txt" ]]; }
has_test_bin() { [[ -f "$1/build/mixxx-test" ]]; }

is_test_binary_stale() {
    local bin="$1/build/mixxx-test"
    [[ -f "$bin" ]] && ldd "$bin" 2>/dev/null | grep -q "not found"
}

is_dirty_tree() {
    ! env GIT_PAGER=cat git -C "$1" diff --quiet 2>/dev/null || \
    ! env GIT_PAGER=cat git -C "$1" diff --cached --quiet 2>/dev/null
}

build_signature() {
    local dir="$1" bin="$1/build/mixxx-test" cache="$1/build/CMakeCache.txt"
    [[ -f "$bin" && -f "$cache" ]] || return 1
    local head bin_mtime cache_hash linked_library_hash
    head=$(env GIT_PAGER=cat git -C "$dir" rev-parse HEAD)
    bin_mtime=$(stat -c %Y "$bin")
    cache_hash=$(sha256sum "$cache" | cut -d' ' -f1)
    linked_library_hash=$(ldd "$bin" | \
        awk '$2 == "=>" && $3 ~ /^\// {print $3} $1 ~ /^\// {print $1}' | \
        sort -u | while IFS= read -r library; do stat -c '%n:%Y:%s' "$library"; done | \
        sha256sum | cut -d' ' -f1)
    printf '%s %s %s %s %s' "$head" "$bin_mtime" "$cache_hash" \
        "$linked_library_hash" "$MANIFEST_HASH"
}

write_build_stamp() {
    local dir="$1" name="$2" signature
    is_dirty_tree "$dir" && return 1
    signature=$(build_signature "$dir") || return 1
    printf '%s\n' "$signature" > "$CACHE_DIR/${name}.built"
}

build_stamp_valid() {
    local dir="$1" name="$2" signature
    [[ -f "$CACHE_DIR/${name}.built" ]] || return 1
    is_dirty_tree "$dir" && return 1
    is_test_binary_stale "$dir" && return 1
    signature=$(build_signature "$dir") || return 1
    [[ "$(<"$CACHE_DIR/${name}.built")" == "$signature" ]]
}

test_sentinel_valid() {
    local dir="$1" name="$2" signature status_value
    [[ -f "$CACHE_DIR/${name}.tested" ]] || return 1
    signature=$(build_signature "$dir") || return 1
    read -r _ _ _ _ _ status_value < "$CACHE_DIR/${name}.tested"
    [[ "$(<"$CACHE_DIR/${name}.tested")" == "$signature pass" && "$status_value" == "pass" ]]
}

test_records() {
    manifest_query branch-records test
    printf 'integration\tintegration\tupstream/main\tfalse\ttrue\ttrue\ttrue\t-\n'
}

gate_records() {
    manifest_query branch-records gate
    printf 'integration\tintegration\tupstream/main\tfalse\ttrue\ttrue\ttrue\t-\n'
}

ensure_build_config() {
    local dir="$1" build_dir="$1/build"
    [[ -f "$build_dir/CMakeCache.txt" ]] || return 0
    if ! grep -q '^CCACHE_SUPPORT:BOOL=ON$' "$build_dir/CMakeCache.txt" || \
       ! grep -q '^CMAKE_BUILD_TYPE:STRING=RelWithDebInfo$' "$build_dir/CMakeCache.txt"; then
        echo "  refreshing build configuration for $(basename "$dir")"
        CCACHE_BASEDIR="$dir" cmake -S "$dir" -B "$build_dir" \
            -DCCACHE_SUPPORT=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo > /dev/null
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
# Processes manifest branches in dependency order and rebases each onto either
# its declared base or its first declared dependency.

rebase_all() {
    _T_REBASE_START=$(date +%s)
    validate_manifest || return 1
    status "PHASE rebase_all — fetching upstream"
    env GIT_PAGER=cat git -C "$MIXXX_MAIN" config rerere.enabled false
    env GIT_PAGER=cat git -C "$MIXXX_MAIN" fetch upstream

    local failed=() succeeded=() _ref name base _rebase _test _integrate _gate dependency dir target
    while IFS=$'\t' read -r _ref name base _rebase _test _integrate _gate dependency _pr_head; do
        dir="$MIXXX_DEV/$name"
        target="$base"
        [[ "$dependency" != "-" ]] && target="$dependency"
        if is_dirty_tree "$dir"; then
            status "  FAILED $name — dirty worktree must be committed or stashed"
            failed+=("$name")
            continue
        fi
        status "rebase: $name onto $target"
        if env GIT_PAGER=cat git -C "$dir" rebase "$target"; then
            status "  $name — rebased"
            succeeded+=("$name")
        else
            status "  FAILED $name — aborting rebase"
            env GIT_PAGER=cat git -C "$dir" rebase --abort 2>/dev/null || true
            failed+=("$name")
        fi
    done < <(manifest_query branch-records rebase)

    _T_REBASE_END=$(date +%s)
    _REBASE_N_OK=${#succeeded[@]}; _REBASE_N_SKIP=0; _REBASE_N_FAIL=${#failed[@]}
    status "DONE rebase_all: ${#succeeded[@]} ok  ${#failed[@]} failed"
    if [[ ${#failed[@]} -gt 0 ]]; then
        printf '  FAILED: %s\n' "${failed[@]}"
        return 1
    fi
}

# ── mode: remerge_integration ──────────────────────────────────────────────────
# Builds the candidate in a temporary detached worktree. The checked-out
# integration branch is updated only after every merge and infrastructure restore
# succeeds, so conflicts and interruptions leave it untouched.

remerge_integration() {
    validate_manifest || return 1
    local current_branch pre_reset_sha candidate_sha branch f unresolved
    local temp_root="" temp_tree=""
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
        status "DRY-RUN remerge_integration: candidate will be built but not installed"
    fi
    current_branch=$(env GIT_PAGER=cat git -C "$MIXXX_MAIN" branch --show-current 2>/dev/null || true)
    if [[ "$current_branch" != "integration" ]]; then
        status "ABORT remerge_integration: MIXXX_MAIN is on '${current_branch:-detached}', not integration"
        return 1
    fi
    if is_dirty_tree "$MIXXX_MAIN"; then
        status "ABORT remerge_integration: integration has tracked changes; commit or stash them first"
        return 1
    fi
    if ! env GIT_PAGER=cat git -C "$MIXXX_MAIN" fetch upstream; then
        status "ABORT remerge_integration: upstream fetch failed"
        return 1
    fi

    pre_reset_sha=$(env GIT_PAGER=cat git -C "$MIXXX_MAIN" rev-parse HEAD)
    cleanup_remerge() {
        trap - INT TERM
        if [[ -n "$temp_tree" ]]; then
            env GIT_PAGER=cat git -C "$MIXXX_MAIN" worktree remove --force "$temp_tree" >/dev/null 2>&1 || true
        fi
        [[ -z "$temp_root" ]] || rmdir "$temp_root" >/dev/null 2>&1 || true
        env GIT_PAGER=cat git -C "$MIXXX_MAIN" config rerere.enabled false || true
    }
    trap 'cleanup_remerge; exit 130' INT TERM
    if ! temp_root=$(mktemp -d /tmp/mixxx-integration-remerge.XXXXXX); then
        cleanup_remerge
        status "ABORT remerge_integration: failed to create temporary directory"
        return 1
    fi
    temp_tree="$temp_root/worktree"
    if ! env GIT_PAGER=cat git -C "$MIXXX_MAIN" config rerere.enabled true; then
        cleanup_remerge
        status "ABORT remerge_integration: failed to enable scoped rerere"
        return 1
    fi

    status "PHASE remerge_integration — transactionally merging ${#INTEGRATION_BRANCHES[@]} branches"
    if ! env GIT_PAGER=cat git -C "$MIXXX_MAIN" worktree add --detach "$temp_tree" upstream/main >/dev/null; then
        cleanup_remerge
        status "ABORT remerge_integration: failed to create temporary worktree"
        return 1
    fi

    local merged=() idx=0
    for branch in "${INTEGRATION_BRANCHES[@]}"; do
        (( idx++ )) || true
        status "  merge [$idx/${#INTEGRATION_BRANCHES[@]}] $branch"
        if env GIT_PAGER=cat git -C "$temp_tree" merge --no-edit "$branch"; then
            merged+=("$branch")
            continue
        fi
        unresolved=$(env GIT_PAGER=cat git -C "$temp_tree" diff --name-only --diff-filter=U 2>/dev/null)
        if [[ -z "$unresolved" ]] && \
           env GIT_PAGER=cat git -C "$temp_tree" rev-parse --verify -q MERGE_HEAD >/dev/null && \
           GIT_EDITOR=true env GIT_PAGER=cat git -C "$temp_tree" commit --no-edit; then
            status "  OK (rerere): $branch"
            merged+=("$branch")
            continue
        fi
        env GIT_PAGER=cat git -C "$temp_tree" merge --abort >/dev/null 2>&1 || true
        cleanup_remerge
        status "BLOCKED remerge_integration: conflict in $branch; integration remains at $pre_reset_sha"
        status "  Resolve the branch interaction, then rerun the complete remerge"
        return 1
    done

    local restore_files=()
    for f in "${INFRASTRUCTURE_FILES[@]}"; do
        if env GIT_PAGER=cat git -C "$MIXXX_MAIN" cat-file -e "$pre_reset_sha:$f" 2>/dev/null; then
            restore_files+=("$f")
        else
            cleanup_remerge
            status "ABORT remerge_integration: $f is absent from pre-reset integration"
            return 1
        fi
    done
    if ! env GIT_PAGER=cat git -C "$temp_tree" checkout "$pre_reset_sha" -- "${restore_files[@]}"; then
        cleanup_remerge
        status "ABORT remerge_integration: infrastructure restore failed"
        return 1
    fi
    if ! env GIT_PAGER=cat git -C "$temp_tree" diff --cached --quiet; then
        if ! GIT_EDITOR=true env GIT_PAGER=cat git -C "$temp_tree" commit \
                -m "restore integration infrastructure after remerge" >/dev/null; then
            cleanup_remerge
            status "ABORT remerge_integration: infrastructure commit failed"
            return 1
        fi
    fi

    if ! candidate_sha=$(env GIT_PAGER=cat git -C "$temp_tree" rev-parse HEAD); then
        cleanup_remerge
        status "ABORT remerge_integration: failed to resolve candidate SHA"
        return 1
    fi
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
        cleanup_remerge
        status "DRY-RUN DONE remerge_integration: ${#merged[@]} branches merged; candidate $candidate_sha NOT installed (integration remains at $pre_reset_sha)"
        return 0
    fi
    if ! env GIT_PAGER=cat git -C "$MIXXX_MAIN" reset --hard "$candidate_sha"; then
        cleanup_remerge
        status "ABORT remerge_integration: failed to install candidate $candidate_sha"
        return 1
    fi
    cleanup_remerge
    status "DONE remerge_integration: ${#merged[@]} branches merged at $candidate_sha"
}

# ── mode: push_changed_branches ──────────────────────────────────────────────
# Pushes feature/bugfix branches to origin ONLY when their patch content has
# actually changed relative to what is already on origin. A pure rebase (same
# diff, different base commit) is not pushed — avoids wasteful CI runs.
#
# Compares stable patch IDs against each branch's manifest-declared base. Branches
# with rebase=false are deliberately excluded.

push_changed_branches() {
    validate_manifest || return 1
    status "PHASE push_changed_branches — smart-diff push (only content changes)"
    if ! env GIT_PAGER=cat git -C "$MIXXX_MAIN" fetch origin --prune; then
        status "ABORT push_changed_branches: origin fetch failed"
        return 1
    fi

    local pushed=() skipped=() failed=()
    local branch_name name base _rebase _test _integrate _gate _dependency pr_head external dir local_pids origin_pids push_target
    while IFS=$'\t' read -r branch_name name base _rebase _test _integrate _gate _dependency pr_head external; do
        dir="$MIXXX_DEV/$name"
        # External branches track upstream PRs by other contributors — never push to origin
        if [[ "$external" == "true" ]]; then
            skipped+=("$name (external)")
            continue
        fi
        # When pr_head is declared (legacy undated PR head), push to that ref
        # so the upstream PR receives the content. Otherwise push to the local ref.
        push_target="$branch_name"
        [[ "$pr_head" != "-" && -n "$pr_head" ]] && push_target="$pr_head"
        if ! env GIT_PAGER=cat git -C "$dir" rev-parse --verify "origin/$push_target" >/dev/null 2>&1; then
            if env GIT_PAGER=cat git -C "$dir" push --force-with-lease origin "HEAD:refs/heads/$push_target"; then
                status "  $name — pushed (new remote branch $push_target)"
                pushed+=("$name")
            else
                status "  $name — push FAILED"
                failed+=("$name")
            fi
            continue
        fi

        local_pids=$(env GIT_PAGER=cat git -C "$dir" log --no-merges -p "${base}..HEAD" 2>/dev/null | \
            git patch-id --stable 2>/dev/null | awk '{print $1}' | sort)
        origin_pids=$(env GIT_PAGER=cat git -C "$dir" log --no-merges -p \
            "${base}..origin/${push_target}" 2>/dev/null | \
            git patch-id --stable 2>/dev/null | awk '{print $1}' | sort)
        if [[ "$local_pids" == "$origin_pids" ]]; then
            skipped+=("$name")
            continue
        fi

        if env GIT_PAGER=cat git -C "$dir" push --force-with-lease origin "HEAD:refs/heads/$push_target"; then
            status "  $name — pushed (content changed → $push_target)"
            pushed+=("$name")
        else
            status "  $name — push FAILED"
            failed+=("$name")
        fi
    done < <(manifest_query branch-records rebase)

    echo ""
    status "DONE push_changed_branches: ${#pushed[@]} pushed  ${#skipped[@]} skipped (unchanged)  ${#failed[@]} failed"
    if [[ ${#skipped[@]} -gt 0 ]]; then
        printf '%b\n' "  ${_C_DIM}Skipped (pure rebase, no CI value): ${skipped[*]}${_C_NC}"
    fi
    [[ ${#failed[@]} -eq 0 ]] || { printf '  FAILED: %s\n' "${failed[@]}"; return 1; }
}

# ── mode: build_all_tests ─────────────────────────────────────────────────────
# Configures missing build trees in parallel, then incrementally builds every
# manifest test branch and the combined integration tree serially. A successful
# clean build writes a signature bound to HEAD, CMakeCache, binary mtime, and the
# authoritative manifest.

build_all_tests() {
    _T_BUILD_START=$(date +%s)
    validate_manifest || return 1
    status "PHASE build_all_tests"
    trap kill_trap INT TERM

    local dirs=() names=() to_configure=()
    local _ref name _base _rebase _test _integrate _gate _dependency dir
    while IFS=$'\t' read -r _ref name _base _rebase _test _integrate _gate _dependency _pr_head; do
        if [[ "$name" == "integration" ]]; then dir="$MIXXX_MAIN"; else dir="$MIXXX_DEV/$name"; fi
        dirs+=("$dir")
        names+=("$name")
        has_build "$dir" || to_configure+=("$dir")
    done < <(test_records)

    local configure_failed=() _pids=() _pdirs=() _i
    for dir in "${to_configure[@]}"; do
        name=$(basename "$dir")
        local cfg_log="$CACHE_DIR/configure-${name}.log"
        status "  configure (launch) $name"
        CCACHE_BASEDIR="$dir" cmake -S "$dir" -B "$dir/build" -GNinja \
            -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCCACHE_SUPPORT=ON > "$cfg_log" 2>&1 &
        _pids+=($!)
        _pdirs+=("$dir")
    done
    for _i in "${!_pids[@]}"; do
        name=$(basename "${_pdirs[$_i]}")
        if wait "${_pids[$_i]}"; then
            status "  configure OK: $name"
        else
            status "  configure FAILED: $name (log: $CACHE_DIR/configure-${name}.log)"
            configure_failed+=("$name")
        fi
    done
    if [[ ${#configure_failed[@]} -gt 0 ]]; then
        printf '  configure FAILED: %s\n' "${configure_failed[@]}"
        return 1
    fi

    local config_failed=()
    for dir in "${dirs[@]}"; do
        if ! ensure_build_config "$dir"; then
            config_failed+=("$(basename "$dir")")
        fi
    done
    if [[ ${#config_failed[@]} -gt 0 ]]; then
        printf '  configuration FAILED: %s\n' "${config_failed[@]}"
        return 1
    fi

    local built=() build_failed=() idx=0 _phase_t0; _phase_t0=$(date +%s)
    for _i in "${!dirs[@]}"; do
        dir="${dirs[$_i]}"; name="${names[$_i]}"
        (( idx++ )) || true
        local _t0; _t0=$(date +%s)
        if is_dirty_tree "$dir"; then
            status "  build BLOCKED: $name has tracked changes"
            build_failed+=("$name")
            _BUILD_RESULTS+=("${name}:0:fail")
            continue
        fi
        if build_with_progress "$dir" mixxx-test "$idx" "${#dirs[@]}" && \
           ! is_test_binary_stale "$dir" && write_build_stamp "$dir" "$name"; then
            local _et=$(( $(date +%s) - _t0 ))
            $_HAS_TTY && printf "\n"
            status "  build OK: $name (${_et}s)"
            built+=("$name")
            _BUILD_RESULTS+=("${name}:${_et}:ok")
            eta_line "$idx" "${#dirs[@]}" "$(( $(date +%s) - _phase_t0 ))" "build"
        else
            local _et=$(( $(date +%s) - _t0 ))
            $_HAS_TTY && printf "\n"
            status "  build FAILED: $name (${_et}s)"
            build_failed+=("$name")
            _BUILD_RESULTS+=("${name}:${_et}:fail")
        fi
    done
    _T_BUILD_END=$(date +%s)
    trap - INT TERM

    status "DONE build_all_tests: ${#built[@]} ok  ${#build_failed[@]} failed"
    if [[ ${#build_failed[@]} -gt 0 ]]; then
        printf '  FAILED: %s\n' "${build_failed[@]}"
        return 1
    fi
    ccache -s 2>/dev/null || true
}

rebuild_tests_serial() {
    build_all_tests
}

# ── mode: build_integration_binary ───────────────────────────────────────────
# Builds the main mixxx executable (not mixxx-test) for the integration worktree
# so one has a runnable local binary after a remerge. Called by the full pipeline
# and by --quick-integration.

build_integration_binary() {
    local dir="$MIXXX_MAIN"
    status "PHASE build_integration_binary — building mixxx for integration tree"
    has_build "$dir" || {
        local cfg_log="$CACHE_DIR/configure-integration.log"
        status "  configure (launch) integration"
        CCACHE_BASEDIR="$dir" cmake -S "$dir" -B "$dir/build" -GNinja \
            -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCCACHE_SUPPORT=ON > "$cfg_log" 2>&1 \
            || { status "configure FAILED: integration (log: $cfg_log)"; return 1; }
    }
    ensure_build_config "$dir" || { status "configuration FAILED: integration"; return 1; }
    if is_dirty_tree "$dir"; then
        status "  build BLOCKED: integration has tracked changes"
        return 1
    fi
    local _t0; _t0=$(date +%s)
    if build_with_progress "$dir" mixxx 1 1; then
        local _et=$(( $(date +%s) - _t0 ))
        $_HAS_TTY && printf "\n"
        status "  build OK: integration mixxx (${_et}s)"
    else
        local _et=$(( $(date +%s) - _t0 ))
        $_HAS_TTY && printf "\n"
        status "  build FAILED: integration mixxx (${_et}s)"
        return 1
    fi
    status "DONE build_integration_binary: ~/src/mixxx-dev/integration/build/mixxx"
}

# ── mode: run_tests_serial ────────────────────────────────────────────────────
# Runs every manifest-selected test tree plus the combined integration tree.
# Passing sentinels are valid only while their corresponding build signature is
# unchanged; dirty trees and missing build stamps are blocking.

run_tests_serial() {
    _T_TEST_START=$(date +%s)
    validate_manifest || return 1
    trap kill_trap INT TERM

    local dirs_with_tests=() names_with_tests=() skipped_names=() blocked=()
    local _ref name _base _rebase _test _integrate _gate _dependency dir
    while IFS=$'\t' read -r _ref name _base _rebase _test _integrate _gate _dependency _pr_head; do
        if [[ "$name" == "integration" ]]; then dir="$MIXXX_MAIN"; else dir="$MIXXX_DEV/$name"; fi
        if is_dirty_tree "$dir"; then
            blocked+=("$name (tracked changes)")
        elif ! build_stamp_valid "$dir" "$name"; then
            blocked+=("$name (missing or stale build stamp)")
        elif test_sentinel_valid "$dir" "$name"; then
            skipped_names+=("$name")
            _TEST_RESULTS+=("${name}:0:skip")
        else
            dirs_with_tests+=("$dir")
            names_with_tests+=("$name")
        fi
    done < <(test_records)

    if [[ ${#blocked[@]} -gt 0 ]]; then
        status "BLOCKED run_tests_serial: build clean trees first"
        printf '  - %s\n' "${blocked[@]}"
        return 1
    fi

    local total=${#dirs_with_tests[@]} passed=() failed=() idx=0 _i
    status "PHASE run_tests_serial ($total to run, ${#skipped_names[@]} current)"
    for _i in "${!dirs_with_tests[@]}"; do
        dir="${dirs_with_tests[$_i]}"; name="${names_with_tests[$_i]}"
        (( idx++ )) || true
        local log="$TEST_LOG_DIR/${name}.log" timeout_secs=420 t0
        t0=$(date +%s)
        status "test [$idx/$total] $name (log: $log)"
        ( while true; do
              sleep 30
              local count elapsed
              count=$(grep -ac 'RUN      ' "$log" 2>/dev/null || true)
              elapsed=$(( $(date +%s) - t0 ))
              status "  ... [$idx/$total] $name — ${count:-?} tests, ${elapsed}s elapsed"
          done ) &
        local heartbeat_pid=$!
        if (cd "$dir/build" && timeout "$timeout_secs" ./mixxx-test \
                --gtest_filter="-${KNOWN_FAILING}") > "$log" 2>&1; then
            kill "$heartbeat_pid" 2>/dev/null; wait "$heartbeat_pid" 2>/dev/null || true
            local elapsed signature
            elapsed=$(( $(date +%s) - t0 ))
            signature=$(build_signature "$dir")
            printf '%s pass\n' "$signature" > "$CACHE_DIR/${name}.tested"
            status "  PASS [$idx/$total] $name (${elapsed}s)"
            passed+=("$name")
            _TEST_RESULTS+=("${name}:${elapsed}:pass")
        else
            local rc=$? elapsed signature
            kill "$heartbeat_pid" 2>/dev/null; wait "$heartbeat_pid" 2>/dev/null || true
            elapsed=$(( $(date +%s) - t0 ))
            signature=$(build_signature "$dir" 2>/dev/null || echo "unknown unknown unknown unknown $MANIFEST_HASH")
            printf '%s fail\n' "$signature" > "$CACHE_DIR/${name}.tested"
            if [[ $rc -eq 124 ]]; then
                status "  TIMEOUT [$idx/$total] $name (${elapsed}s)"
            else
                status "  FAIL [$idx/$total] $name (${elapsed}s, see $log)"
            fi
            failed+=("$name")
            _TEST_RESULTS+=("${name}:${elapsed}:fail")
        fi
        [[ $(( idx % 5 )) -eq 0 ]] && sys_stats
        eta_line "$idx" "$total" "$(( $(date +%s) - _T_TEST_START ))" "test"
    done
    _T_TEST_END=$(date +%s)
    trap - INT TERM

    local total_pass=$(( ${#passed[@]} + ${#skipped_names[@]} ))
    status "DONE run_tests_serial: ${#passed[@]} pass  ${#failed[@]} fail  ${#skipped_names[@]} current"
    if [[ ${#failed[@]} -gt 0 ]]; then
        printf '  FAILED: %s\n' "${failed[@]}"
        return 1
    fi
    printf '%s %s %d\n' "$(env GIT_PAGER=cat git -C "$MIXXX_MAIN" rev-parse HEAD)" \
        "$MANIFEST_HASH" "$total_pass" > "$SENTINEL_FILE"
}

# ── mode: push_integration / push_integrating ─────────────────────────────────

push_integration() {
    status "PHASE push_integration"
    if ! env GIT_PAGER=cat git -C "$MIXXX_MAIN" fetch origin; then
        status "ABORT push_integration: origin fetch failed"
        return 1
    fi
    if ! env GIT_PAGER=cat git -C "$MIXXX_MAIN" push --force-with-lease origin \
            "integration:refs/heads/integration"; then
        status "ABORT push_integration: push failed"
        return 1
    fi
    status "DONE integration branch pushed"
}

push_integrating() {
    validate_manifest || return 1
    local blocking=() _ref name _base _rebase _test _integrate _gate _dependency dir
    while IFS=$'\t' read -r _ref name _base _rebase _test _integrate _gate _dependency _pr_head; do
        if [[ "$name" == "integration" ]]; then dir="$MIXXX_MAIN"; else dir="$MIXXX_DEV/$name"; fi
        is_dirty_tree "$dir" && blocking+=("$name (tracked changes)")
        build_stamp_valid "$dir" "$name" || blocking+=("$name (stale or missing build)")
        test_sentinel_valid "$dir" "$name" || blocking+=("$name (stale or missing test pass)")
    done < <(gate_records)
    if [[ ${#blocking[@]} -gt 0 ]]; then
        status "BLOCKED push_integrating: local gate is incomplete"
        printf '  - %s\n' "${blocking[@]}"
        return 1
    fi

    local integration_sha
    integration_sha=$(env GIT_PAGER=cat git -C "$MIXXX_MAIN" rev-parse integration)
    if ! env GIT_PAGER=cat git -C "$MIXXX_MAIN" fetch origin; then
        status "ABORT push_integrating: origin fetch failed"
        return 1
    fi
    env GIT_PAGER=cat git -C "$MIXXX_MAIN" branch -f integrating "$integration_sha"
    if ! env GIT_PAGER=cat git -C "$MIXXX_MAIN" push --force-with-lease origin \
            "$integration_sha:refs/heads/integrating"; then
        status "ABORT push_integrating: push failed"
        return 1
    fi
    status "DONE integrating pushed at $integration_sha — GA CI triggered"
    status "  Monitor: gh run list --workflow $CI_WORKFLOW --branch integrating --commit $integration_sha --repo $REPOSITORY"
}

# ── mode: promote_integrated ──────────────────────────────────────────────────
# Polls the declared CI workflow for the exact origin/integrating SHA. Promotion
# is a fast-forward and is abandoned if integrating moves while CI is running.

promote_integrated() {
    validate_manifest || return 1
    if ! env GIT_PAGER=cat git -C "$MIXXX_MAIN" fetch origin; then
        status "ABORT promote_integrated: origin fetch failed"
        return 1
    fi
    local expected_sha timeout_secs=3600 poll_interval=30 t0 run_line
    local run_id run_status conclusion run_sha elapsed
    expected_sha=$(env GIT_PAGER=cat git -C "$MIXXX_MAIN" rev-parse origin/integrating)
    t0=$(date +%s)
    status "PHASE promote_integrated — waiting for $CI_WORKFLOW at $expected_sha"

    while true; do
        elapsed=$(( $(date +%s) - t0 ))
        if [[ $elapsed -gt $timeout_secs ]]; then
            status "TIMEOUT: exact-SHA CI did not complete within ${timeout_secs}s"
            return 1
        fi
        if ! run_line=$(gh run list --workflow "$CI_WORKFLOW" --branch integrating \
                --commit "$expected_sha" --event push --repo "$REPOSITORY" --limit 1 \
                --json databaseId,status,conclusion,headSha \
                --jq '.[0] | [.databaseId, .status, (.conclusion // ""), .headSha] | join("|")' 2>/dev/null); then
            status "ABORT promote_integrated: unable to query GitHub Actions"
            return 1
        fi
        if [[ -z "$run_line" ]]; then
            status "  waiting for CI run registration (${elapsed}s)"
            sleep "$poll_interval"
            continue
        fi
        IFS='|' read -r run_id run_status conclusion run_sha <<< "$run_line"
        if [[ "$run_sha" != "$expected_sha" ]]; then
            status "ABORT promote_integrated: CI returned unexpected SHA $run_sha"
            return 1
        fi
        status "  run #$run_id: $run_status${conclusion:+/$conclusion} (${elapsed}s)"
        [[ "$run_status" == "completed" ]] && break
        sleep "$poll_interval"
    done

    if [[ "$conclusion" != "success" ]]; then
        status "BLOCKED promote_integrated: exact-SHA CI concluded $conclusion"
        status "  Inspect: gh run view $run_id --repo $REPOSITORY"
        return 1
    fi
    if ! env GIT_PAGER=cat git -C "$MIXXX_MAIN" fetch origin; then
        status "ABORT promote_integrated: final origin fetch failed"
        return 1
    fi
    local current_integrating current_integrated
    current_integrating=$(env GIT_PAGER=cat git -C "$MIXXX_MAIN" rev-parse origin/integrating)
    current_integrated=$(env GIT_PAGER=cat git -C "$MIXXX_MAIN" rev-parse origin/integrated)
    if [[ "$current_integrating" != "$expected_sha" ]]; then
        status "BLOCKED promote_integrated: integrating moved to $current_integrating after CI"
        return 1
    fi
    if [[ "$current_integrated" == "$expected_sha" ]]; then
        status "DONE integrated already equals tested SHA $expected_sha"
        return 0
    fi
    if ! env GIT_PAGER=cat git -C "$MIXXX_MAIN" merge-base --is-ancestor \
            "$current_integrated" "$expected_sha"; then
        status "NOTE promote_integrated: integrated ($current_integrated) is not an ancestor of tested SHA — main moved between candidates; force-updating"
    fi

    env GIT_PAGER=cat git -C "$MIXXX_MAIN" branch -f integrated "$expected_sha"
    if ! env GIT_PAGER=cat git -C "$MIXXX_MAIN" push --force origin \
            "$expected_sha:refs/heads/integrated"; then
        status "ABORT promote_integrated: push failed"
        return 1
    fi
    status "DONE integrated updated to CI-tested SHA $expected_sha"
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
        if [[ "$_r" == ok ]]; then (( ++b_ok )); else (( ++b_fail )); fi
        [[ $_t -gt $slow_bt ]] && { slowest_build="$_n"; slow_bt=$_t; }
    done
    for e in "${_TEST_RESULTS[@]+"${_TEST_RESULTS[@]}"}" ; do
        local _n="${e%%:*}" _r="${e##*:}" _t="${e#*:}"; _t="${_t%%:*}"
        case "$_r" in pass) (( ++t_pass ));; fail) (( ++t_fail ));; skip) (( ++t_skip ));; esac
        [[ $_t -gt $slow_tt && "$_r" != skip ]] && { slowest_test="$_n"; slow_tt=$_t; }
    done
    local rb_c=$(( _REBASE_N_FAIL > 0 )) bi_c=$(( b_fail > 0 )) ts_c=$(( t_fail > 0 ))
    local SEP="${_C_CYN}${_C_BLD}"; local DIV="${_C_DIM}"; local E="${_C_NC}"
    printf '%b\n' "${SEP}═══════════════════════════════════════════════════${E}"
    printf '%b\n' " ${_C_BLD}GRAND SUMMARY  —  $(date '+%Y-%m-%d %H:%M')${E}"
    printf '%b\n' " Total: ${_C_BLD}$(printf '%dm%02ds' $(( total/60 )) $(( total%60 )))${E}"
    printf '%b\n' "${DIV}───────────────────────────────────────────────────${E}"
    printf '%b\n' " ${DIV}Phase       Dur         Result${E}"
    local rc_r rc_b rc_t
    if (( rb_c )); then rc_r="$_C_RED"; else rc_r="$_C_GRN"; fi
    if (( bi_c )); then rc_b="$_C_RED"; else rc_b="$_C_GRN"; fi
    if (( ts_c )); then rc_t="$_C_RED"; else rc_t="$_C_GRN"; fi
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
# Orchestrates manifest validation, dependency-aware rebases, transactional remerge,
# exact builds, serial tests, and both local-tier pushes. Any failed phase is fatal;
# no partial candidate is pushed or promoted.

rebase_merge_test_push() {
    local ts; ts=$(date '+%Y-%m-%d %H:%M')
    echo "╔══════════════════════════════════════════════╗"
    printf  "║  Rebase+Merge+Test+Push — %-20s║\n" "$ts"
    echo "╚══════════════════════════════════════════════╝"
    echo "Real-time status: tail -f $STATUS_FILE"
    echo "Test logs:        tail -f $TEST_LOG_DIR/<worktree>.log"

    rebase_all          || { status "ABORT pipeline: rebase failed"; return 1; }
    remerge_integration || { status "ABORT pipeline: transactional remerge failed"; return 1; }
    build_all_tests     || { status "ABORT pipeline: build failed"; return 1; }
    run_tests_serial    || { status "ABORT pipeline: tests failed"; return 1; }
    build_integration_binary || { status "ABORT pipeline: integration binary build failed"; return 1; }
    push_integration    || return 1
    push_integrating    || return 1
    print_grand_summary true true
}

rebase_merge_test_push_promote() {
    rebase_merge_test_push || return 1
    promote_integrated || {
        status "promote_integrated failed — rerun --promote-integrated after exact-SHA CI passes"
        return 1
    }
}

# ── mode: quick_integration ───────────────────────────────────────────────────
# Rebases, remerges, and builds only the combined integration tree. Skips local
# tests and all remote operations (push, CI, promotion). Use for fast iteration
# when one only needs a runnable integration binary.

quick_integration() {
    local ts; ts=$(date '+%Y-%m-%d %H:%M')
    echo "╔══════════════════════════════════════════════╗"
    printf  "║  Quick Integration — %-20s  ║\n" "$ts"
    echo "╚══════════════════════════════════════════════╝"
    echo "Real-time status: tail -f $STATUS_FILE"

    rebase_all          || { status "ABORT pipeline: rebase failed"; return 1; }
    remerge_integration || { status "ABORT pipeline: transactional remerge failed"; return 1; }

    # Build only the integration worktree, not all test branches.
    _T_BUILD_START=$(date +%s)
    validate_manifest || return 1
    status "PHASE quick_integration — building integration tree only"
    trap kill_trap INT TERM

    local dir="$MIXXX_MAIN"
    has_build "$dir" || {
        local cfg_log="$CACHE_DIR/configure-integration.log"
        status "  configure (launch) integration"
        CCACHE_BASEDIR="$dir" cmake -S "$dir" -B "$dir/build" -GNinja \
            -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCCACHE_SUPPORT=ON > "$cfg_log" 2>&1 \
            || { status "configure FAILED: integration (log: $cfg_log)"; return 1; }
    }
    ensure_build_config "$dir" || { status "configuration FAILED: integration"; return 1; }

    local _t0; _t0=$(date +%s)
    if is_dirty_tree "$dir"; then
        status "  build BLOCKED: integration has tracked changes"
        return 1
    fi
    if build_with_progress "$dir" mixxx-test 1 1 && \
       ! is_test_binary_stale "$dir" && write_build_stamp "$dir" "integration"; then
        local _et=$(( $(date +%s) - _t0 ))
        $_HAS_TTY && printf "\n"
        status "  build OK: integration (${_et}s)"
    else
        local _et=$(( $(date +%s) - _t0 ))
        $_HAS_TTY && printf "\n"
        status "  build FAILED: integration (${_et}s)"
        return 1
    fi
    _T_BUILD_END=$(date +%s)
    trap - INT TERM

    build_integration_binary || { status "ABORT quick_integration: integration binary build failed"; return 1; }

    ccache -s 2>/dev/null || true
    status "DONE quick_integration: integration tree built; tests and remote CI skipped"
}

# ── mode: sync_gist ────────────────────────────────────────────────────────────
# Syncs every infrastructure file to the Gist after a successful pipeline run or
# on demand. Reads the Gist ID from the document header. Non-fatal — a gist sync
# failure warns but does not block branch operations.

GIST_ID="5fb35c401736efed47ad7d78268c80b6"

sync_gist() {
    status "PHASE sync_gist — syncing infrastructure files to gist $GIST_ID"
    local file gist_name failed=()
    local -A gist_map=(
        ["INTEGRATION.md"]="INTEGRATION.md"
        ["mixxx-milkii-integration-update-branches.sh"]="mixxx-milkii-integration-update-branches.sh"
        ["mixxx-milkii-integration-pre-push.sh"]="mixxx-milkii-integration-pre-push.sh"
        ["mixxx-milkii-integration-gdb-run.sh"]="mixxx-milkii-integration-gdb-run.sh"
        [".github/workflows/mixxx-milkii-integration-manjaro-release.yml"]="mixxx-milkii-integration-manjaro-release.yml"
        [".github/workflows/mixxx-milkii-integration-auto-promote.yml"]="mixxx-milkii-integration-auto-promote.yml"
    )
    for file in "${!gist_map[@]}"; do
        local local_path="$MIXXX_MAIN/$file"
        local gist_name="${gist_map[$file]}"
        if [[ ! -f "$local_path" ]]; then
            status "  WARN: $file not found, skipping"
            failed+=("$file")
            continue
        fi
        if gh gist edit "$GIST_ID" --filename "$gist_name" "$local_path" 2>/dev/null; then
            status "  OK synced: $gist_name"
        else
            status "  FAIL syncing: $gist_name"
            failed+=("$file")
        fi
    done
    if [[ ${#failed[@]} -gt 0 ]]; then
        status "WARN sync_gist: ${#failed[@]} file(s) failed to sync"
        return 1
    fi
    status "DONE sync_gist: all infrastructure files synced"
}

# ── dispatch ───────────────────────────────────────────────────────────────────

# Optional --dry-run as second arg: currently only --remerge-integration honours
# it (builds the candidate in a temp worktree but skips the final reset). Other
# modes ignore it.
DRY_RUN=0
[[ "${2:-}" == "--dry-run" ]] && DRY_RUN=1

case "${1:-}" in
    --validate-manifest)         validate_manifest ;;
    --rebuild-tests)             rebuild_tests_serial ;;
    --build-all-tests)           build_all_tests ;;
    --run-tests)                 run_tests_serial ;;
    --remerge-integration)       remerge_integration ;;
    --push-changed)              push_changed_branches ;;
    --push-integrating)          push_integrating ;;
    --promote-integrated)        promote_integrated ;;
    --sync-gist)                 sync_gist ;;
    --rebase-merge-test-push)    rebase_merge_test_push; sync_gist || true ;;
    --rebase-merge-test-push-promote) rebase_merge_test_push_promote; sync_gist || true ;;
    --quick-integration)         quick_integration ;;
    "")                          rebase_all ;;
    *) echo "Usage: $0 [--validate-manifest | --rebuild-tests | --build-all-tests | --run-tests | --remerge-integration [--dry-run] | --push-changed | --push-integrating | --promote-integrated | --sync-gist | --rebase-merge-test-push | --rebase-merge-test-push-promote | --quick-integration]"; exit 1 ;;
esac
