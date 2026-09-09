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
manifest_packs() {
  local forge="$1"; shift
  echo "core"
  local s
  for s in "$@"; do
    echo "stacks/${s}"
  done
  echo "forges/${forge}"
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
  sed -e 's/^[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "${list}" \
  | while IFS='|' read -r src target mode; do
      [ -n "${src}" ] || continue
      printf '%s|%s|%s|%s\n' "${pack}" "${src}" "${target}" "${mode}"
    done
}
