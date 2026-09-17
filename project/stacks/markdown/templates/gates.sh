#!/usr/bin/env bash
# The gates that must be green before a commit. Project-owned: devkit-sync
# never overwrites this file, so adjust the commands to fit the repository.
#
# Usage:  bash .devkit/gates.sh [links|index|headings|all]
#         (no argument means all)
#
# Nothing here needs a toolchain. A documentation repository is cloned by
# people who do not have one installed, and a gate they cannot run is a gate
# that does not bind them - so these use git, find, awk and sed and nothing
# else.
set -uo pipefail

cd "$(git rev-parse --show-toplevel)"

# Tracked and untracked-but-not-ignored, because the gate runs before anything
# is staged: a file added and not yet committed is exactly the one whose broken
# link gets missed. Ignored files stay out, which is what keeps the personal
# AGENTS.local.md from being held to the rules.
#
# Read into an array rather than word-split out of a string, so a path with a
# space in it stays one path.
MD_FILES=()
read_md_files() {
  local f
  MD_FILES=()
  while IFS= read -r f; do
    [ -n "${f}" ] && MD_FILES+=("${f}")
  done < <(git ls-files --cached --others --exclude-standard -- '*.md' | sort -u)
}

# Link targets, one `<file>|<line>|<target>` per link, fenced code blocks
# skipped. A link inside a code block is an example of a link, not one.
#
# Inline links `[text](target)` and reference definitions `[id]: target`.
# Titles (`(target "Title")`) and angle brackets (`(<target>)`) are stripped
# here so the caller only ever sees a path.
md_links() {   # <file>...
  awk '
    FNR == 1 { fence = 0 }
    /^[[:space:]]*(```|~~~)/ { fence = !fence; next }
    fence { next }

    function emit(raw,   t, p) {
      t = raw
      sub(/^[[:space:]]+/, "", t); sub(/[[:space:]]+$/, "", t)
      # A title after the target: cut at the first blank.
      p = index(t, " "); if (p > 0) t = substr(t, 1, p - 1)
      gsub(/^<|>$/, "", t)
      if (t == "") return
      print FILENAME "|" FNR "|" t
    }

    {
      s = $0
      while (match(s, /\]\([^()]*\)/)) {
        emit(substr(s, RSTART + 2, RLENGTH - 3))
        s = substr(s, RSTART + RLENGTH)
      }
    }

    /^[[:space:]]*\[[^]]+\]:[[:space:]]*[^[:space:]]/ {
      emit(substr($0, index($0, "]:") + 2))
    }
  ' "$@"
}

# Repo-relative path of a link target seen in <file>. A leading / is taken as
# repo-relative, everything else as relative to the file's own directory.
resolve() {   # <file> <target>
  local dir target="$2"
  case "${target}" in
    /*) printf '%s\n' "${target#/}"; return ;;
  esac
  dir="$(dirname "$1")"
  [ "${dir}" = "." ] && { printf '%s\n' "${target}"; return; }
  printf '%s\n' "${dir}/${target}"
}

# Every relative link resolves to something that exists. This is the one
# mistake a reader hits and a writer never does.
gate_links() {
  local file line target path fail=0
  read_md_files
  [ "${#MD_FILES[@]}" -gt 0 ] || return 0

  while IFS='|' read -r file line target; do
    case "${target}" in
      ""|\#*) continue ;;                      # a link into the same document
      http://*|https://*|mailto:*|ftp://*) continue ;;
      *://*) continue ;;                       # any other scheme
    esac
    target="${target%%#*}"                     # drop the anchor
    [ -n "${target}" ] || continue
    path="$(resolve "${file}" "${target}")"
    [ -e "${path}" ] && continue
    echo "${file}:${line}: link target does not exist: ${target}"
    fail=1
  done < <(md_links "${MD_FILES[@]}")

  return "${fail}"
}

# The targets an index file links to, as repo-relative paths.
index_targets() {   # <index file>
  local file line target
  while IFS='|' read -r file line target; do
    case "${target}" in ""|\#*|*://*|mailto:*) continue ;; esac
    target="${target%%#*}"
    [ -n "${target}" ] || continue
    resolve "${file}" "${target}"
  done < <(md_links "$1")
}

# Every document under docs/ has a row in the index next to it, and every
# subdirectory is reached through its own README.md. A document that is not in
# the index is a document nobody finds.
#
# The other direction - a row pointing at a file that does not exist - is what
# gate_links already reports, so it is not checked twice here.
gate_index() {
  [ -d docs ] || return 0
  local dir index targets f fail=0 sub

  while IFS= read -r index; do
    dir="$(dirname "${index}")"
    targets="$(index_targets "${index}")"

    while IFS= read -r f; do
      [ -n "${f}" ] || continue
      [ "${f}" = "${index}" ] && continue
      printf '%s\n' "${targets}" | grep -Fxq -- "${f}" && continue
      echo "${index}: no row for ${f}"
      fail=1
    done < <(find "${dir}" -maxdepth 1 -type f -name '*.md' | sed 's#^\./##' | sort)

    while IFS= read -r sub; do
      [ -n "${sub}" ] || continue
      printf '%s\n' "${targets}" | grep -Fxq -- "${sub}/README.md" && continue
      printf '%s\n' "${targets}" | grep -Fxq -- "${sub}" && continue
      echo "${index}: no row for the ${sub}/ index"
      fail=1
    done < <(find "${dir}" -mindepth 1 -maxdepth 1 -type d | sed 's#^\./##' | sort)
  done < <(find docs -type f -name 'README.md' | sed 's#^\./##' | sort)

  return "${fail}"
}

# Exactly one H1 per document, and no level skipped under it. A document that
# needs a second H1 is two documents.
# A file with no heading at all is skipped: that is a fragment, not a document
# - an import stub, a snippet - and demanding an H1 of it would mean keeping a
# list of filenames in here, which is the one thing a pack must not carry.
# Once a file does have headings, the first one is an H1 and there is only one.
#
# One awk run per file: ENDFILE, which would allow a single run over all of
# them, is a GNU extension, and this script has to work wherever the repository
# is cloned.
gate_headings() {
  local f fail=0
  read_md_files
  [ "${#MD_FILES[@]}" -gt 0 ] || return 0

  for f in "${MD_FILES[@]}"; do
    awk '
      /^[[:space:]]*(```|~~~)/ { fence = !fence; next }
      fence { next }

      /^#+[[:space:]]/ {
        match($0, /^#+/)
        level = RLENGTH
        if (level > 6) next          # seven or more is not a heading
        if (level == 1) {
          h1++
          if (h1 == 2) { print FILENAME ":" FNR ": a second H1 - this is two documents"; bad = 1 }
        } else if (prev == 0) {
          print FILENAME ":" FNR ": starts at H" level ", not H1"
          bad = 1
        } else if (level > prev + 1) {
          print FILENAME ":" FNR ": H" prev " jumps to H" level
          bad = 1
        }
        prev = level
      }

      END { exit bad ? 1 : 0 }
    ' "${f}" || fail=1
  done

  return "${fail}"
}

# Expectation per gate, printed when a gate fails.
gate_expectation() {
  case "$1" in
    links)    echo "every relative link resolves to a file that exists" ;;
    index)    echo "every document under docs/ has a row in the index next to it" ;;
    headings) echo "exactly one H1 per document, no skipped level" ;;
  esac
}

# --- runner, do not edit below unless you know why ---------------------------

GATES="links index headings"

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
