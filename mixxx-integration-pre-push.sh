#!/bin/bash
# Pre-push hook logic for mxmilkiib/mixxx.
# This file is committed to the integration branch and versioned alongside
# mixxx-integration-update-branches.sh. The actual .git/hooks/pre-push is a
# thin delegate that execs this script, so hook logic is tracked in git.
# Gist: https://gist.github.com/mxmilkiib/5fb35c401736efed47ad7d78268c80b6
#
# Behaviour:
#   1. Runs clang-format diff check on changed lines (not full files).
#   2. Runs mixxx-test from $REPO_ROOT/build (skips gracefully if binary missing
#      or has stale shared libs after a system update).
#   3. Allows all pushes to mxmilkiib/* remotes unconditionally.
#   4. For all other remotes (upstream PRs etc.), blocks pushes that touch
#      local-only files: INTEGRATION.md, the integration script, the pre-push
#      script, and the GDB helper — these must never reach mixxxdj/mixxx.
#
# KNOWN_FAILING must be kept in sync with the same constant in
# mixxx-integration-update-branches.sh. Remove entries once the upstream
# fix is merged into mixxxdj/mixxx main.

remote="$1"
url="$2"

# ── 1. clang-format style check (diff only, not full files) ───────────────────
echo "Running clang-format style check on changed lines..."
REPO_ROOT="$(git rev-parse --show-toplevel)"

if command -v git-clang-format &> /dev/null || git clang-format --help &> /dev/null; then
    style_diff=$(git clang-format --diff HEAD~1 -- "*.cpp" "*.h" 2>/dev/null)
    if [ -n "$style_diff" ] && \
       [ "$style_diff" != "no modified files to format" ] && \
       [ "$style_diff" != "clang-format did not modify any files" ]; then
        echo "Style check failed! Your changes need formatting:"
        echo "$style_diff" | head -30
        echo ""
        echo "Run: git clang-format HEAD~1"
        echo "Then: git add -u && git commit --amend --no-edit"
        exit 1
    fi
    echo "Style check passed!"
else
    echo "Warning: git-clang-format not found, skipping style check"
fi

# ── 2. test suite (main worktree build only) ───────────────────────────────────
# Skips silently if binary is absent or has missing shared libs (stale after a
# system update). Full worktree test coverage is provided by --run-tests.
echo "Running Mixxx tests before push..."
BUILD_DIR="$REPO_ROOT/build"

#   ControllerScriptEngineLegacyTimerTest.*: coTimerId ControlPotmeter max=50 clamped QTimer IDs;
#     ALL timer tests filtered (not just singleShot*) because beginTimer_repeatedTimer leaves
#     corrupted ID-50 state that causes downstream MidiMappings JS tests to hang indefinitely.
#   keepWithespaceKey: getKeyText() returns internal enum string instead of display format
KNOWN_FAILING='ControllerScriptEngineLegacyTimerTest.*:TrackMetadataExportTest.keepWithespaceKey'

HOOK_TIMEOUT=420
if [ -f "$BUILD_DIR/mixxx-test" ]; then
    if ldd "$BUILD_DIR/mixxx-test" 2>/dev/null | grep -q "not found"; then
        echo "Warning: mixxx-test has missing shared libs (stale binary) — skipping tests."
        echo "Rebuild with: cmake --build $BUILD_DIR --target mixxx-test"
    else
        cd "$BUILD_DIR"
        timeout "$HOOK_TIMEOUT" ./mixxx-test --gtest_filter="-${KNOWN_FAILING}"
        rc=$?
        cd - > /dev/null
        if [ $rc -eq 124 ]; then
            echo "Tests TIMED OUT after ${HOOK_TIMEOUT}s — possible hang (Behringer_CMD_MM1 timer bug?)."
            echo "Push skipped. Investigate with: cd $BUILD_DIR && ./mixxx-test --gtest_filter=MidiMappings"
            exit 1
        elif [ $rc -ne 0 ]; then
            echo "Tests failed! Push aborted."
            echo "Fix the failing tests before pushing."
            exit 1
        fi
        echo "All tests passed!"
    fi
else
    echo "Warning: mixxx-test not found at $BUILD_DIR/mixxx-test, skipping tests"
fi

# ── 3. allow all pushes to personal fork ──────────────────────────────────────
if echo "$url" | grep -qi "mxmilkiib"; then
    exit 0
fi

# ── 4. block local-only files from reaching non-personal remotes ───────────────
# These files are personal-workflow files that MUST NOT reach mixxxdj/mixxx.
while read local_ref local_oid remote_ref remote_oid; do
    if [ "$local_oid" = "0000000000000000000000000000000000000000" ]; then
        continue
    fi
    if [ "$remote_oid" = "0000000000000000000000000000000000000000" ]; then
        range="$local_oid --not --remotes=$remote"
    else
        range="$remote_oid..$local_oid"
    fi
    protected_files="INTEGRATION.md mixxx-integration-gdb-run.sh mixxx-integration-update-branches.sh mixxx-integration-pre-push.sh"
    for f in $protected_files; do
        if git log --diff-filter=ACDMR --name-only --pretty=format: $range -- "$f" | grep -q .; then
            echo "ERROR: Push blocked. $f must not be pushed to $remote ($url)."
            echo "       This file is local-only for mxmilkiib/mixxx."
            exit 1
        fi
    done
done

exit 0
