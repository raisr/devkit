#!/usr/bin/env bash
# The gates that must be green before a commit. Project-owned: devkit-sync
# never overwrites this file, so adjust the commands to fit the repository.
#
# Usage:  bash .devkit/gates.sh [restore|build|test|all]
#         (no argument means all)
#
# NEVER EXECUTED. This file was written from the MSBuild, NuGet and VSTest
# command surface, not from a working build. The first repository that uses it
# is what verifies it - expect to fix it gate by gate, and fix it upstream in
# the devkit rather than only here.
#
# A repository that drives its build through a build script of its own replaces
# the gate bodies below with a call into it. The gates are what must pass; how
# they are invoked belongs to the project.
set -uo pipefail

cd "$(git rev-parse --show-toplevel)"

SLN="{{SOLUTION}}"

# Where MSBuild and VSTest live is a property of the machine, not of the
# repository, so they are looked up rather than hard-coded. vswhere ships with
# every Visual Studio installer since 2017 and always sits at this path.
VSWHERE="/c/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe"

find_tool() {   # <vswhere -find pattern>
  [ -x "${VSWHERE}" ] || return 1
  "${VSWHERE}" -latest -prerelease -products '*' \
    -requires Microsoft.Component.MSBuild -find "$1" 2>/dev/null \
    | tr -d '\r' | head -1
}

MSBUILD="$(find_tool 'MSBuild\**\Bin\MSBuild.exe' || true)"
VSTEST="$(find_tool 'Common7\IDE\Extensions\TestPlatform\vstest.console.exe' || true)"

need_msbuild() {
  [ -n "${MSBUILD}" ] || { echo "MSBuild.exe not found through vswhere" >&2; return 1; }
}

gate_restore() {
  need_msbuild || return 1
  "${MSBUILD}" "${SLN}" -t:restore -nologo -verbosity:minimal
}

gate_build() {
  need_msbuild || return 1
  "${MSBUILD}" "${SLN}" -warnaserror -nologo -verbosity:minimal
}

gate_test() {
  [ -n "${VSTEST}" ] || { echo "vstest.console.exe not found" >&2; return 1; }
  # Built test assemblies, taken from the output folders rather than a list
  # kept by hand. Adjust the pattern if the repository names them differently.
  local -a assemblies=()
  while IFS= read -r a; do assemblies+=("${a}"); done < <(
    find . -path '*/bin/*' -name '*.Tests.*.dll' -not -path './.git/*' | sort
  )
  [ "${#assemblies[@]}" -gt 0 ] || { echo "no built test assemblies found" >&2; return 1; }
  "${VSTEST}" "${assemblies[@]}" /nologo
}

# Expectation per gate, printed when a gate fails.
gate_expectation() {
  case "$1" in
    restore) echo "all packages resolved" ;;
    build)   echo "0 warnings, 0 errors" ;;
    test)    echo "all tests green" ;;
  esac
}

# --- runner, do not edit below unless you know why ---------------------------

GATES="restore build test"

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
