#!/usr/bin/env bash
# Reads the per-pack manifest.list files and emits one normalised line per
# entry. Sourced by bootstrap.sh and by the devkit-sync skill - never run.
#
# Expects DEVKIT_PROJECT_DIR to point at the project/ directory of a devkit
# checkout.
#
# Emitted line:  <pack>|<source, relative to pack>|<target, relative to repo>|<mode>

# manifest_packs <forge> <stack>...
# Order matters: core first, then stacks in the order given, then the forge.
# Blocks are appended to a shared target in exactly this order.
#
# A manifest.list may open with `+<pack>` lines. Those packs are emitted first,
# which is how a stack pack pulls in rules shared with another one - see
# stacks/dotnet-core and stacks/dotnet-legacy, which both pull in shared/dotnet.
# A pack under shared/ is deliberately not selectable with --stack: on its own
# it installs rules without the gates and templates that make them enforceable.
manifest_packs() {
  local forge="$1"; shift
  local seen=" core "
  echo "core"
  local s dep
  for s in "$@"; do
    while IFS= read -r dep; do
      case "${seen}" in *" ${dep} "*) continue ;; esac
      seen="${seen}${dep} "
      echo "${dep}"
    done < <(manifest_requires "stacks/${s}")
    echo "stacks/${s}"
  done
  echo "forges/${forge}"
}

# manifest_requires <pack> - the packs named by `+<pack>` lines, in order.
manifest_requires() {
  local list="${DEVKIT_PROJECT_DIR}/$1/manifest.list"
  [ -f "${list}" ] || return 0
  sed -nE 's/^\+[[:space:]]*([^[:space:]]+)[[:space:]]*$/\1/p' "${list}"
}

# manifest_lines <pack>
manifest_lines() {
  local pack="$1"
  local list="${DEVKIT_PROJECT_DIR}/${pack}/manifest.list"
  if [ ! -f "${list}" ]; then
    echo "devkit: no manifest.list in project/${pack}" >&2
    return 1
  fi
  local src target mode
  # `+<pack>` lines are dependencies, read by manifest_packs, not file entries.
  sed -e 's/^[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' -e '/^+/d' "${list}" \
  | while IFS='|' read -r src target mode; do
      [ -n "${src}" ] || continue
      printf '%s|%s|%s|%s\n' "${pack}" "${src}" "${target}" "${mode}"
    done
}
