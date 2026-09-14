#!/usr/bin/env bash
# The gates that must be green before a commit in this repository.
#
# A consumer repository gets this file from a stack pack and adapts it. devkit
# has no stack pack, so its gates are written here directly - and they check the
# things that are specific to a repository whose product is other repositories:
# that every file in a pack is actually installed by a manifest, that both forge
# adapters still offer the same functions, and that the generated skill stubs
# have not fallen behind their source.
#
# Usage:  bash .devkit/gates.sh [syntax|fixture|manifest|forge|stubs|all]
#         (no argument means all)
set -uo pipefail

cd "$(git rev-parse --show-toplevel)"

# Tracked and untracked-but-not-ignored, because the gate runs before anything
# is staged: a file added and not yet committed is exactly the one whose
# manifest entry gets forgotten.
repo_files() {   # [pathspec...]
  git ls-files --cached --others --exclude-standard -- "$@" | sort -u
}

# Every shell script must parse, and block.awk must be a valid awk program -
# both are shipped into other repositories, where a syntax error is not ours to
# discover.
gate_syntax() {
  local f fail=0
  while IFS= read -r f; do
    bash -n "${f}" || fail=1
  done < <(repo_files '*.sh')
  BLOCK_ID=gate BLOCK_SRC=/dev/null awk -f project/block.awk /dev/null > /dev/null || fail=1
  return "${fail}"
}

# The sample consumer repository, built and bootstrapped from scratch, then
# checked assertion by assertion. This is the only test devkit has.
gate_fixture() {
  local out repo rc=0
  out="$(mktemp -d)"
  repo="$(bash test/build-sample-repo.sh --out "${out}")" || { rm -rf "${out}"; return 1; }
  bash project/bootstrap.sh --repo "${repo}" --forge github --stack dotnet-core \
    --workflow full > /dev/null || rc=1
  [ "${rc}" -eq 0 ] && { bash test/check-sample-repo.sh "${repo}" || rc=1; }
  rm -rf "${out}"
  return "${rc}"
}

# A file under a pack that no manifest.list installs is never copied anywhere,
# so it looks official and does nothing. The tooling below project/ is the
# deliberate exception: it runs the installation, it is not part of it.
gate_manifest() {
  local DEVKIT_PROJECT_DIR="${PWD}/project"
  # shellcheck source=../project/manifest.sh
  . "${DEVKIT_PROJECT_DIR}/manifest.sh"

  local installed="" pack p src target mode f missing=""
  for pack in core $(ls -d project/shared/*/ project/stacks/*/ project/forges/*/ 2>/dev/null \
                     | sed 's#^project/##; s#/$##'); do
    [ -f "project/${pack}/manifest.list" ] || continue
    while IFS='|' read -r p src target mode; do
      if [ "${mode}" = "dir" ]; then
        while IFS= read -r f; do
          installed="${installed}${f}
"
        done < <(find "project/${p}/${src}" -type f | sort)
      else
        installed="${installed}project/${p}/${src}
"
      fi
    done < <(manifest_lines "${pack}")
  done

  while IFS= read -r f; do
    case "${f}" in
      project/bootstrap.sh|project/manifest.sh|project/block.awk) continue ;;
      */manifest.list) continue ;;
    esac
    printf '%s' "${installed}" | grep -Fxq -- "${f}" || missing="${missing}${f}
"
  done < <(repo_files project/)

  [ -z "${missing}" ] && return 0
  echo "under project/, but no manifest.list installs them:"
  printf '%s' "${missing}" | sed 's/^/  /'
  return 1
}

# Both forge packs define the same function names, because the skills call only
# those. A function added to one and not the other breaks the other forge
# silently, in a repository nobody here is looking at.
gate_forge() {
  local f names ref="" refname=""
  for f in project/forges/*/forge.sh; do
    names="$(grep -oE '^forge_[a-z_]+\(\)' "${f}" | sort)"
    if [ -z "${ref}" ]; then
      ref="${names}"; refname="${f}"; continue
    fi
    if [ "${names}" != "${ref}" ]; then
      echo "the forge contract differs between ${refname} and ${f}:"
      diff <(printf '%s\n' "${ref}") <(printf '%s\n' "${names}") | sed 's/^/  /'
      return 1
    fi
  done
}

# .claude/skills holds generated pointers at project/core/skills, not copies.
# A stub whose frontmatter has fallen behind is the worst kind of stale: the
# description decides whether the skill fires, so the symptom is nothing
# happening at all.
gate_stubs() {
  bash .devkit/stubs.sh --verify
}

gate_expectation() {
  case "$1" in
    syntax)   echo "every .sh parses, block.awk is valid awk" ;;
    fixture)  echo "the sample repo bootstraps and every assertion holds" ;;
    manifest) echo "every file in a pack is installed by its manifest.list" ;;
    forge)    echo "github and gitlab expose the same forge_* functions" ;;
    stubs)    echo ".claude/skills matches project/core/skills" ;;
  esac
}

# --- runner, do not edit below unless you know why ---------------------------

GATES="syntax manifest forge stubs fixture"

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
  local want="${1:-all}" fail=0 g
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
