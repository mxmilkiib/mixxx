#!/bin/bash
# Pre-push hook logic for mxmilkiib/mixxx.
# The actual .git/hooks/pre-push delegates to this versioned script.
# Gist: https://gist.github.com/mxmilkiib/5fb35c401736efed47ad7d78268c80b6

set -euo pipefail

remote="$1"
url="$2"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INTEGRATION_DOC="$SCRIPT_DIR/INTEGRATION.md"
REPO_ROOT="$(git rev-parse --show-toplevel)"
BUILD_DIR="$REPO_ROOT/build"
HOOK_TIMEOUT=420
BUILD_JOBS=$(( $(nproc) - 2 )); [[ $BUILD_JOBS -lt 1 ]] && BUILD_JOBS=1

manifest_query() {
    python3 - "$INTEGRATION_DOC" "$@" <<'PY'
import json
import pathlib
import re
import sys

text = pathlib.Path(sys.argv[1]).read_text()
match = re.search(
    r"<!-- MIXXX_INTEGRATION_MANIFEST_START -->\s*```json\s*(.*?)\s*```\s*<!-- MIXXX_INTEGRATION_MANIFEST_END -->",
    text,
    re.DOTALL,
)
if not match:
    raise SystemExit("integration manifest not found")
data = json.loads(match.group(1))
if sys.argv[2] == "test-filter":
    print(":".join(data["test_exclusions"]))
elif sys.argv[2] == "infrastructure-files":
    print("\n".join(data["infrastructure_files"]))
elif sys.argv[2] == "branch-base":
    defaults = data["branch_defaults"]
    ref = sys.argv[3]
    for branch in data["branches"]:
        if branch["ref"] == ref:
            print(branch.get("base", defaults["base"]))
            break
    else:
        raise SystemExit(f"branch absent from manifest: {ref}")
else:
    raise SystemExit("unknown manifest query")
PY
}

KNOWN_FAILING="$(manifest_query test-filter)" || exit 1
mapfile -t PROTECTED_FILES < <(manifest_query infrastructure-files)
[[ ${#PROTECTED_FILES[@]} -gt 0 ]] || { echo "ERROR: Manifest has no infrastructure files."; exit 1; }
[[ ! -t 0 ]] || { echo "ERROR: Pre-push ref updates are required on stdin."; exit 1; }
mapfile -t UPDATES
[[ ${#UPDATES[@]} -gt 0 ]] || { echo "ERROR: Git supplied no pre-push ref updates."; exit 1; }

has_non_delete=false
declare local_branch declared_base format_base infra_base
declare -a format_bases=() format_heads=()
for update in "${UPDATES[@]}"; do
    read -r local_ref local_oid remote_ref remote_oid <<< "$update"
    [[ "$local_oid" == "0000000000000000000000000000000000000000" ]] && continue
    has_non_delete=true
    local_branch="${local_ref#refs/heads/}"
    if ! declared_base=$(manifest_query branch-base "$local_branch" 2>/dev/null); then
        declared_base=upstream/main
    fi
    if [[ "$remote_oid" == "0000000000000000000000000000000000000000" ]]; then
        format_base=$(git merge-base "$local_oid" "$declared_base")
    else
        if ! env GIT_PAGER=cat git cat-file -e "$remote_oid^{commit}" 2>/dev/null; then
            env GIT_PAGER=cat git fetch --no-tags "$remote" "$remote_ref"
        fi
        # For force-pushes where remote_oid is not an ancestor of local_oid
        # (e.g. PR head repoint), use the declared base so only local commits
        # are format-checked, not upstream commits in the old→new range.
        if env GIT_PAGER=cat git merge-base --is-ancestor "$remote_oid" "$local_oid" 2>/dev/null; then
            format_base="$remote_oid"
        else
            format_base=$(git merge-base "$local_oid" "$declared_base")
        fi
    fi
    case "$remote_ref" in
        refs/heads/integration|refs/heads/integrating|refs/heads/integrated)
            # Promotion branches carry merge commits from multiple feature
            # branches; each branch was already format-checked individually.
            # git clang-format cannot traverse merge-commit ranges, and the
            # infrastructure file check is also skipped for these refs.
            continue
            ;;
    esac
    format_bases+=("$format_base")
    format_heads+=("$local_oid")
    # Infrastructure file check: only check local commits above the declared
    # base, not upstream commits in the old→new range. Upstream commits that
    # touch develop.yml etc. are fine — they are not our integration changes.
    infra_base=$(git merge-base "$local_oid" "$declared_base")
    for file in "${PROTECTED_FILES[@]}"; do
        if env GIT_PAGER=cat git log --diff-filter=ACDMR --name-only --pretty=format: \
                "${infra_base}..${local_oid}" -- "$file" | grep -q .; then
            echo "ERROR: $file is integration-only and cannot be pushed to $remote_ref ($url)."
            exit 1
        fi
    done
done

$has_non_delete || exit 0

echo "Running clang-format style checks for every pushed range..."
if ! command -v git-clang-format >/dev/null 2>&1; then
    echo "ERROR: git-clang-format is required before pushing."
    exit 1
fi
for index in "${!format_heads[@]}"; do
    if ! style_diff=$(git clang-format --diff "${format_bases[$index]}" \
            "${format_heads[$index]}" -- "*.cpp" "*.h" 2>/dev/null); then
        echo "ERROR: git clang-format could not inspect ${format_bases[$index]}..${format_heads[$index]}."
        exit 1
    fi
    if [[ -n "$style_diff" &&
          "$style_diff" != "no modified files to format" &&
          "$style_diff" != "clang-format did not modify any files" ]]; then
        echo "Style check failed for ${format_bases[$index]}..${format_heads[$index]}."
        printf '%s\n' "$style_diff" | head -30
        exit 1
    fi
done

if [[ ! -f "$BUILD_DIR/CMakeCache.txt" ]]; then
    echo "ERROR: Build directory is not configured at $BUILD_DIR."
    exit 1
fi
if ! grep -q '^CMAKE_BUILD_TYPE:STRING=RelWithDebInfo$' "$BUILD_DIR/CMakeCache.txt"; then
    echo "ERROR: $BUILD_DIR must use CMAKE_BUILD_TYPE=RelWithDebInfo."
    exit 1
fi
if ! CCACHE_BASEDIR="$REPO_ROOT" nice -n 15 cmake --build "$BUILD_DIR" \
        --target mixxx-test -- -j"$BUILD_JOBS"; then
    echo "ERROR: mixxx-test failed to build."
    exit 1
fi
if [[ ! -f "$BUILD_DIR/mixxx-test" ]] || \
   ldd "$BUILD_DIR/mixxx-test" 2>/dev/null | grep -q "not found"; then
    echo "ERROR: mixxx-test is missing or has unresolved shared libraries."
    exit 1
fi
if ! env GIT_PAGER=cat git -C "$REPO_ROOT" diff --quiet || \
   ! env GIT_PAGER=cat git -C "$REPO_ROOT" diff --cached --quiet; then
    echo "ERROR: Tracked working-tree changes make the test result ambiguous."
    exit 1
fi

echo "Running Mixxx tests before push..."
set +e
(cd "$BUILD_DIR" && timeout "$HOOK_TIMEOUT" ./mixxx-test \
    --gtest_filter="-${KNOWN_FAILING}")
rc=$?
set -e
if [[ $rc -eq 0 ]]; then
    echo "All tests passed."
    exit 0
fi
if [[ $rc -eq 124 ]]; then
    echo "ERROR: Tests timed out after ${HOOK_TIMEOUT}s."
else
    echo "ERROR: Tests failed with exit code $rc."
fi
exit 1
