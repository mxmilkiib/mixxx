#!/bin/bash

# Mixxx GDB runner with datetime logging
# Usage: mixxx-milkii-integration-gdb-run.sh [additional Mixxx arguments]
# Gist: https://gist.github.com/mxmilkiib/5fb35c401736efed47ad7d78268c80b6

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
USERNAME=$(id -un)
LOG_FILE="${SCRIPT_DIR}/mixxx_gdb-${USERNAME}_${TIMESTAMP}.log"
MIXXX_ARGS=(--developer --controller-debug --debug-assert-break "$@")

MIXXX_EXE=""
if [[ -x "${SCRIPT_DIR}/build/mixxx" ]]; then
    MIXXX_EXE="${SCRIPT_DIR}/build/mixxx"
elif [[ -x "${PWD}/mixxx" ]]; then
    MIXXX_EXE="${PWD}/mixxx"
elif [[ -x "${HOME}/src/mixxx/build/mixxx" ]]; then
    MIXXX_EXE="${HOME}/src/mixxx/build/mixxx"
fi

if [[ -z "$MIXXX_EXE" ]]; then
    echo "Error: Could not find mixxx in ${SCRIPT_DIR}/build, the current directory, or ${HOME}/src/mixxx/build." >&2
    exit 1
fi

# GDB convenience variables must remain literal.
# shellcheck disable=SC2016
GDB_OPTS=(
    --batch
    --return-child-result
    -ex 'set pagination off'
    -ex 'set print pretty on'
    -ex 'set print frame-arguments scalars'
    -ex 'set print thread-events off'
    -ex 'set confirm off'
    -ex 'set debuginfod enabled on'
    -ex 'handle SIG32 nostop noprint'
    -ex 'handle SIGPIPE nostop noprint'
    -ex 'handle SIGUSR1 nostop noprint'
    -ex 'handle SIGUSR2 nostop noprint'
    -ex run
    -ex 'if $_isvoid($_exitcode)'
    -ex 'bt full'
    -ex 'info registers'
    -ex 'thread apply all bt'
    -ex end
)

printf -v CMD '%q ' gdb "${GDB_OPTS[@]}" --args "$MIXXX_EXE" "${MIXXX_ARGS[@]}"
CMD="${CMD% }"
echo "Logging to: $LOG_FILE"

set +e
{
    echo "# $CMD"
    echo
    gdb "${GDB_OPTS[@]}" --args "$MIXXX_EXE" "${MIXXX_ARGS[@]}" 2>&1
} | tee "$LOG_FILE"
EXIT_CODE=${PIPESTATUS[0]}
set -e

if [[ $EXIT_CODE -eq 0 ]]; then
    echo "Clean exit, log saved to: $LOG_FILE"
else
    echo "Exit code $EXIT_CODE, log saved to: $LOG_FILE"
fi
exit "$EXIT_CODE"
