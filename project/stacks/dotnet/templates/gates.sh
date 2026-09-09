#!/usr/bin/env bash
# The gates that must be green before a commit. Project-owned: devkit-sync
# never overwrites this file, so adjust the commands to fit the repository.
#
# Usage:  bash .devkit/gates.sh [build|test|format|all]
#         (no argument means all)
set -uo pipefail

cd "$(git rev-parse --show-toplevel)"

SLN="{{SOLUTION}}"

gate_build()  { dotnet build  "${SLN}" --nologo; }
gate_test()   { dotnet test   "${SLN}" --nologo; }
gate_format() { dotnet format "${SLN}" --verify-no-changes; }

# Expectation per gate, printed when a gate fails.
gate_expectation() {
  case "$1" in
    build)  echo "0 warnings, 0 errors" ;;
    test)   echo "all tests green" ;;
    format) echo "no formatting changes needed" ;;
  esac
}

# --- runner, do not edit below unless you know why ---------------------------

GATES="build test format"

run_one() {
  local name="$1" log
  log="$(mktemp)"
  printf '=== %s ===\n' "${name}"
  if "gate_${name}" > "${log}" 2>&1; then
    printf '  PASS\n'
    rm -f "${log}"
    return 0
  fi
  printf '  FAIL - expected: %s\n' "$(gate_expectation "${name}")"
  tail -n 15 "${log}" | sed 's/^/    /'
  rm -f "${log}"
  return 1
}

main() {
  local want="${1:-all}" fail=0
  if [ "${want}" != "all" ]; then
    run_one "${want}"
    exit $?
  fi
  for g in ${GATES}; do
    run_one "${g}" || fail=1
    echo
  done
  if [ "${fail}" -eq 0 ]; then
    echo "GATES: all green"
  else
    echo "GATES: not ready"
  fi
  exit "${fail}"
}

main "$@"
