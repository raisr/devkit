#!/usr/bin/env bash
# Puts the devkit files into a repository: rules, skills, config and templates.
#
# Run it once when a repository starts, or again to add a stack. It writes
# files and nothing else - no staging, no commit. Review with `git status`.
#
#   d="$(mktemp -d)" \
#     && git clone --depth 1 https://github.com/raisr/devkit "$d/devkit" \
#     && bash "$d/devkit/project/bootstrap.sh" --forge github --stack dotnet-core
#
# Re-running is safe: managed files are rewritten, blocks are replaced between
# their markers, and templates are left alone once they exist - except the two
# keys in .devkit/config.sh that name the installed packs, which this script
# owns and keeps in step with the flags it was given.
set -euo pipefail

DEVKIT_PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVKIT_ROOT="$(cd "${DEVKIT_PROJECT_DIR}/.." && pwd)"
# shellcheck source=manifest.sh
. "${DEVKIT_PROJECT_DIR}/manifest.sh"

SOURCE_URL="https://github.com/raisr/devkit"
STACKS=()
FORGE=""
WORKFLOW="light"
ASSIGNEE=""
MAIN_BRANCH=""
REPO=""
DRY_RUN=0

usage() {
  cat <<'USAGE'
Usage: bootstrap.sh --forge <github|gitlab> [options]

  --forge <name>       required; which forge pack to install
  --stack <name>       stack pack to install; repeat for more than one
  --workflow <mode>    full | light   (default: light)
  --assignee <name>    who gets assigned to a pull or merge request
  --main-branch <name> default branch (default: what origin says, else HEAD)
  --repo <path>        repository to write into (default: the current one)
  --dry-run            print what would happen, write nothing
  -h, --help           this text
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --forge)       FORGE="$2"; shift 2 ;;
    --stack)       STACKS+=("$2"); shift 2 ;;
    --workflow)    WORKFLOW="$2"; shift 2 ;;
    --assignee)    ASSIGNEE="$2"; shift 2 ;;
    --main-branch) MAIN_BRANCH="$2"; shift 2 ;;
    --repo)        REPO="$2"; shift 2 ;;
    --dry-run)     DRY_RUN=1; shift ;;
    -h|--help)     usage; exit 0 ;;
    *)             echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

die() { echo "devkit: $*" >&2; exit 1; }

[ -n "${FORGE}" ] || { usage >&2; die "--forge is required"; }
[ -d "${DEVKIT_PROJECT_DIR}/forges/${FORGE}" ] || die "no forge pack ${FORGE}"
for s in ${STACKS[@]+"${STACKS[@]}"}; do
  [ -d "${DEVKIT_PROJECT_DIR}/stacks/${s}" ] || die "no stack pack ${s}"
done
case "${WORKFLOW}" in full|light) ;; *) die "--workflow must be full or light" ;; esac

if [ -n "${REPO}" ]; then
  REPO="$(cd "${REPO}" && git rev-parse --show-toplevel)"
else
  REPO="$(git rev-parse --show-toplevel)" || die "not inside a git repository"
fi

PROJECT_NAME="$(basename "${REPO}")"

# The repository's default branch, not whatever happens to be checked out:
# bootstrapping an existing repository happens on a feature branch, and that
# name must never end up in DEVKIT_MAIN_BRANCH. Everything here is offline -
# `git remote show origin` would go to the network and hang without access.
default_branch() {
  local b
  b="$(git -C "${REPO}" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)" \
    && { echo "${b#origin/}"; return; }
  for b in main master; do
    git -C "${REPO}" show-ref --verify --quiet "refs/remotes/origin/${b}" \
      && { echo "${b}"; return; }
  done
  # No remote at all - the greenfield case, where the current branch is right.
  b="$(git -C "${REPO}" symbolic-ref --quiet --short HEAD 2>/dev/null || echo main)"
  case "${b}" in
    main|master|trunk) ;;
    *) echo "devkit: no default branch on a remote; falling back to the current branch '${b}'." >&2
       echo "devkit: pass --main-branch if that is not the default branch." >&2 ;;
  esac
  echo "${b}"
}
[ -n "${MAIN_BRANCH}" ] || MAIN_BRANCH="$(default_branch)"
[ -n "${ASSIGNEE}" ] || ASSIGNEE="$(git -C "${REPO}" config user.name || echo "")"

DEVKIT_COMMIT="$(git -C "${DEVKIT_ROOT}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
DEVKIT_DATE="$(git -C "${DEVKIT_ROOT}" log -1 --format=%cs 2>/dev/null || echo unknown)"
TODAY="$(date +%F)"

# The solution or workspace file the dotnet gates run against. Tool directories
# are skipped, not just .git: Visual Studio keeps a copy of the solution in
# .vs/, and a dot directory sorts before src/, so without this the gates end up
# pointing at a cache that is not even in the repository.
SOLUTION="$(cd "${REPO}" && find . -maxdepth 3 \( -name "*.slnx" -o -name "*.sln" \) \
  -not -path "./.*/*" -not -path "*/bin/*" -not -path "*/obj/*" \
  2>/dev/null | sed "s#^\./##" | sort | head -1)"
SOLUTION_TODO="TODO-set-the-solution-path"
[ -n "${SOLUTION}" ] || SOLUTION="${SOLUTION_TODO}"

# Imports of the rule files this repository actually receives. These have to be
# `@`-imports: Claude Code follows those into context, a Markdown link never.
#
# The list is read out of the manifests rather than built from the --stack
# flags, because a stack pack can pull in rules shared with another pack, and
# those have to be imported too.
rule_imports() {
  local pack p src target mode stem
  while IFS= read -r pack; do
    while IFS="|" read -r p src target mode; do
      case "${target}" in AGENTS.local.md) continue ;; AGENTS.*.md) ;; *) continue ;; esac
      stem="${target#AGENTS.}"; stem="${stem%.md}"
      case "${p}" in
        core)     printf '@%s — rules that hold in every repository\n' "${target}" ;;
        forges/*) printf '@%s — conventions for %s\n' "${target}" "${FORGE}" ;;
        *)        printf '@%s — rules for %s\n' "${target}" "${stem}" ;;
      esac
    done < <(manifest_lines "${pack}")
  done < <(manifest_packs "${FORGE}" ${STACKS[@]+"${STACKS[@]}"})
}
# Joined with a literal \n, which sed expands back into newlines on the right
# hand side of the substitution below.
RULE_IMPORTS="$(rule_imports | awk 'NR>1 { printf "\\n" } { printf "%s", $0 }')"

say()   { printf "  %-9s %s\n" "$1" "$2"; }
would() { [ "${DRY_RUN}" -eq 1 ]; }

substitute() {
  sed -e "s|{{PROJECT_NAME}}|${PROJECT_NAME}|g" \
      -e "s|{{FORGE}}|${FORGE}|g" \
      -e "s|{{STACKS}}|${STACKS[*]-}|g" \
      -e "s|{{WORKFLOW}}|${WORKFLOW}|g" \
      -e "s|{{MAIN_BRANCH}}|${MAIN_BRANCH}|g" \
      -e "s|{{ASSIGNEE}}|${ASSIGNEE}|g" \
      -e "s|{{SOLUTION}}|${SOLUTION}|g" \
      -e "s|{{DATE}}|${TODAY}|g" \
      -e "s|{{RULE_IMPORTS}}|${RULE_IMPORTS}|g"
}

hash_of() { git hash-object "$1"; }

# The recorded hash is always the hash of the devkit source file, never of what
# ended up in the repository. For a managed file the two are the same, so a
# mismatch means somebody edited it locally. For a block it is the block
# content, which sync compares against what it extracts from the target. For a
# template it is the upstream version the project started from, so sync can say
# that the template moved on without ever touching the file.
LOCK_FILES=""
KEPT_CHAIN=""
INSTALLED=""     # every repo-relative path this run wrote
DIR_TARGETS=""   # the target directories of dir-mode entries
record() {   # <target> <pack/source> <mode> <source hash> [marker]
  LOCK_FILES="${LOCK_FILES}$1|$2|$3|$4|${5-}
"
}

# --- the modes ---------------------------------------------------------------

apply_managed() {   # <src> <target> <origin>
  local src="$1" target="${REPO}/$2" origin="$3"
  if would; then say managed "$2"; return; fi
  mkdir -p "$(dirname "${target}")"
  cp "${src}" "${target}"
  record "$2" "${origin}" managed "$(hash_of "${src}")"
  INSTALLED="${INSTALLED}$2
"
  say managed "$2"
}

apply_template() {   # <src> <target> <origin>
  local src="$1" target="${REPO}/$2" origin="$3"
  if would; then say template "$2"; return; fi
  # An existing template belongs to the project. It still goes into the lock,
  # so a later sync can tell that the upstream template has moved on.
  if [ -e "${target}" ]; then
    record "$2" "${origin}" template "$(hash_of "${src}")"
    # Two of these carry the import chain. Keeping them is right, but it leaves
    # the rule files on disk with nothing reading them, so it is reported at
    # the end rather than in this one line.
    case "$2" in AGENTS.md|CLAUDE.md) KEPT_CHAIN="${KEPT_CHAIN}$2 " ;; esac
    say kept "$2"
    return
  fi
  mkdir -p "$(dirname "${target}")"
  # A personal AGENTS.local.md, where the developer keeps one, beats the scaffold.
  if [ "$2" = "AGENTS.local.md" ] && [ -f "${HOME}/.claude/AGENTS.local.md" ]; then
    cp "${HOME}/.claude/AGENTS.local.md" "${target}"
    say template "$2  (from ~/.claude/AGENTS.local.md)"
  else
    substitute < "${src}" > "${target}"
    say template "$2"
  fi
  record "$2" "${origin}" template "$(hash_of "${src}")"
}

# A target a previous devkit installed as a managed file carries devkit lines
# and no markers. Putting a block above them leaves those lines behind as if
# the project had written them - and because these formats let the later line
# win, the stale copy would then override the block. Silently, which is the
# failure the block mode exists to end.
#
# The lock from that previous run is what answers it: it records the mode and
# the hash of the devkit source each file came from. A managed file is a
# verbatim copy of its source, so a hash that still matches means nobody
# touched it and the block may replace the file whole. A hash that does not
# match means the project edited the file, and nothing here can tell its lines
# from the devkit's - so the block goes in above them and the run says so.
MIGRATE_BY_HAND="" # former managed targets this repository had edited

lock_managed_hash() {   # <target> - source hash a previous run recorded as managed
  local lock="${REPO}/devkit.lock.json" entry
  [ -f "${lock}" ] || return 0
  entry="$(grep -F "\"path\": \"$1\"," "${lock}" | head -1 || true)"
  case "${entry}" in *'"mode": "managed"'*) ;; *) return 0 ;; esac
  printf '%s' "${entry}" | sed -n 's/.*"hash": "\([0-9a-f]*\)".*/\1/p'
}

# Prints `replace`, `by-hand`, or nothing at all.
migration_of() {   # <target path> <target, repo-relative>
  local recorded
  [ -f "$1" ] || return 0
  grep -q '^# >>> devkit:' "$1" && return 0
  recorded="$(lock_managed_hash "$2")"
  [ -n "${recorded}" ] || return 0
  if [ "$(hash_of "$1")" = "${recorded}" ]; then echo replace; else echo by-hand; fi
}

apply_block() {   # <src> <target> <marker id> <origin>
  local src="$1" target="${REPO}/$2" id="$3" origin="$4" migrate note=""
  migrate="$(migration_of "${target}" "$2")"
  case "${migrate}" in
    replace) note="  (was a managed file)" ;;
    by-hand) note="  (was a managed file - see MIGRATION below)"
             MIGRATE_BY_HAND="${MIGRATE_BY_HAND}$2
" ;;
  esac
  if would; then say block "$2  [${id}]${note}"; return; fi
  mkdir -p "$(dirname "${target}")"
  if [ ! -e "${target}" ] || [ "${migrate}" = "replace" ]; then : > "${target}"; fi
  BLOCK_SRC="${src}" BLOCK_ID="${id}" awk -f "${DEVKIT_PROJECT_DIR}/block.awk" \
    "${target}" > "${target}.devkit-tmp"
  mv "${target}.devkit-tmp" "${target}"
  record "$2" "${origin}" block "$(hash_of "${src}")" "${id}"
  say block "$2  [${id}]${note}"
}

# DEVKIT_FORGE and DEVKIT_STACKS are the only two keys in the config template
# that are not a project decision: they name the packs this script installed,
# and the devkit-sync collect script reads exactly them to work out which files
# to compare. Left behind on a second run, a repository that picked up another
# stack goes on syncing against the old pack set and never sees the new files -
# silently, because everything else about the run looks right.
#
# So these two lines are rewritten in place, and nothing else in the file is
# touched. Workflow, default branch, assignee and commit approval stay the
# project's: they carry a decision, and --workflow even has a default that would
# quietly undo a deliberate `full`.
update_key() {   # <file> <key> <whole new line> - true when it changed
  local file="$1" key="$2" line="$3"
  if grep -q "^${key}=" "${file}"; then
    grep -qxF -- "${line}" "${file}" && return 1
    would && return 0
    KEY="${key}" LINE="${line}" awk '
      BEGIN { key = ENVIRON["KEY"] "="; n = length(key) }
      substr($0, 1, n) == key { print ENVIRON["LINE"]; next }
      { print }
    ' "${file}" > "${file}.devkit-tmp"
    mv "${file}.devkit-tmp" "${file}"
  else
    # An older config, written before the key existed. Appending is right for a
    # shell file, and the last assignment is the one that counts.
    would || printf '%s\n' "${line}" >> "${file}"
  fi
  return 0
}

sync_pack_keys() {
  local cfg="${REPO}/.devkit/config.sh" changed=""
  [ -f "${cfg}" ] || return 0
  update_key "${cfg}" DEVKIT_FORGE "DEVKIT_FORGE=${FORGE}" \
    && changed="${changed}DEVKIT_FORGE "
  update_key "${cfg}" DEVKIT_STACKS "DEVKIT_STACKS=\"${STACKS[*]-}\"" \
    && changed="${changed}DEVKIT_STACKS "
  [ -n "${changed}" ] || return 0
  say updated ".devkit/config.sh  [${changed% }]"
  echo
}

apply_dir() {   # <src dir> <target dir> <origin>
  local src="$1" target="$2" origin="$3" f rel
  DIR_TARGETS="${DIR_TARGETS}${target}
"
  while IFS= read -r f; do
    rel="${f#"${src}/"}"
    apply_managed "${f}" "${target}/${rel}" "${origin}/${rel}"
  done < <(find "${src}" -type f | sort)
}

# --- run ---------------------------------------------------------------------

echo "devkit ${DEVKIT_COMMIT} (${DEVKIT_DATE})"
echo "  repository : ${REPO}"
echo "  forge      : ${FORGE}"
echo "  stacks     : ${STACKS[*]-none}"
echo "  workflow   : ${WORKFLOW}"
would && echo "  DRY RUN - nothing is written"
echo

while IFS= read -r pack; do
  echo "${pack}"
  while IFS="|" read -r p src target mode; do
    src_path="${DEVKIT_PROJECT_DIR}/${p}/${src}"
    [ -e "${src_path}" ] || die "manifest points at a missing file: project/${p}/${src}"
    case "${mode}" in
      managed)  apply_managed  "${src_path}" "${target}" "${p}/${src}" ;;
      template) apply_template "${src_path}" "${target}" "${p}/${src}" ;;
      dir)      apply_dir      "${src_path}" "${target}" "${p}/${src}" ;;
      block:*)  apply_block    "${src_path}" "${target}" "${mode#block:}" "${p}/${src}" ;;
      *)        die "unknown mode ${mode} for ${p}/${src}" ;;
    esac
  done < <(manifest_lines "${pack}")
  echo
done < <(manifest_packs "${FORGE}" ${STACKS[@]+"${STACKS[@]}"})

sync_pack_keys

if ! would; then
  {
    printf "{\n"
    printf "  \"source\": \"%s\",\n" "${SOURCE_URL}"
    printf "  \"version\": { \"commit\": \"%s\", \"date\": \"%s\" },\n" "${DEVKIT_COMMIT}" "${DEVKIT_DATE}"
    printf "  \"bootstrappedAt\": \"%s\",\n" "${TODAY}"
    printf "  \"flavors\": { \"stacks\": ["
    sep=""
    for s in ${STACKS[@]+"${STACKS[@]}"}; do printf "%s\"%s\"" "${sep}" "${s}"; sep=", "; done
    printf "], \"forge\": \"%s\" },\n" "${FORGE}"
    printf "  \"files\": [\n"
    sep=""
    while IFS="|" read -r t o m h marker; do
      [ -n "${t}" ] || continue
      printf "%s    { \"path\": \"%s\", \"from\": \"%s\", \"mode\": \"%s\", \"hash\": \"%s\"" \
        "${sep}" "${t}" "${o}" "${m}" "${h}"
      [ -z "${marker}" ] || printf ", \"marker\": \"%s\"" "${marker}"
      printf " }"
      sep=$',\n'
    done <<< "${LOCK_FILES}"
    printf "\n  ],\n"
    printf "  \"deviations\": []\n"
    printf "}\n"
  } > "${REPO}/devkit.lock.json"
  say written devkit.lock.json
  echo
fi

echo "Done. Nothing was staged or committed - review with: git -C ${REPO} status"

# No solution was found, so the placeholder went into every template that asks
# for one. Which templates those are is a pack's business, not this script's:
# a repository on a stack that has no solution - or on no stack at all - must
# not be sent off to edit a file that never had the key. So the files are asked
# rather than the flags, and where none carries the placeholder nothing is said.
#
# A template the project already owned is asked too. It keeps the placeholder
# only if nobody ever filled it in, and then the note is still the right one.
placeholder_files() {
  local target rest
  while IFS="|" read -r target rest; do
    [ -n "${target}" ] && [ -f "${REPO}/${target}" ] || continue
    grep -Fq -- "${SOLUTION_TODO}" "${REPO}/${target}" && printf '%s\n' "${target}"
  done <<< "${LOCK_FILES}"
}
if ! would; then
  pending="$(placeholder_files | sort -u)"
  if [ -n "${pending}" ]; then
    echo
    echo "Note: no .sln/.slnx found. Set the solution path yourself in:"
    echo
    printf '%s\n' "${pending}" | sed 's/^/      /'
  fi
fi

# A block target that an older devkit installed as a managed file. Where the
# file was still that devkit's own copy, the block replaced it and there is
# nothing left to decide. Where the project had edited it, its lines and the
# old devkit ones are indistinguishable from here, so both stay - and the ones
# that are stale now sit below the block, where these formats let them win.
if [ -n "${MIGRATE_BY_HAND}" ]; then
  echo
  echo "MIGRATION - these used to be managed files and are devkit blocks now."
  echo "This repository had edited them, so nothing was removed:"
  echo
  printf '%s' "${MIGRATE_BY_HAND}" | sed 's/^/      /'
  echo
  echo "  Keep your own lines. Delete the devkit ones that are now below the"
  echo "  block - a later line beats an earlier one, so they override it."
fi

# A dir target is copied into, never emptied first, so a file the devkit used to
# ship stays behind forever and goes on looking official. Only files inside a
# directory the devkit does install are reported: a project may keep skills of
# its own next to them, and those are not leftovers. Reported, never deleted -
# which of the two it is, is not this script's call.
dir_leftovers() {
  local d f rel sub
  printf '%s' "${DIR_TARGETS}" | while IFS= read -r d; do
    [ -n "${d}" ] && [ -d "${REPO}/${d}" ] || continue
    find "${REPO}/${d}" -type f 2>/dev/null | sort | while IFS= read -r f; do
      rel="${f#"${REPO}/"}"
      printf '%s' "${INSTALLED}" | grep -Fxq -- "${rel}" && continue
      sub="${rel#"${d}/"}"; sub="${sub%%/*}"
      case "${INSTALLED}" in *"${d}/${sub}/"*) printf '%s\n' "${rel}" ;; esac
    done
  done
}
leftovers="$(dir_leftovers)"
if [ -n "${leftovers}" ]; then
  echo
  echo "LEFTOVERS - the devkit no longer ships these, and nothing references them:"
  echo
  printf '%s\n' "${leftovers}" | sed 's/^/      /'
  echo
  echo "  They were not touched. Delete them, or keep them as your own."
fi

# The import chain is what makes the rule files reachable. Where the project
# already owned one of the two files it runs through, the chain now has a gap
# that only a human can close - and a gap here is silent: the files are on
# disk, everything looks installed, and no session reads a single rule.
#
# Only what is genuinely still missing is reported. A converted repository keeps
# these files on every later run too, and a notice that fires when there is
# nothing to do is one nobody reads the third time.
actual_name() {   # <canonical name> - the file as it is really spelled on disk
  ( cd "${REPO}" && ls -1 | grep -ix "$(printf '%s' "$1" | sed 's/\./\\./g')" | head -1 )
}
missing_imports() {   # the @-imports the kept rules file does not have
  local f="${REPO}/$1" target
  while IFS= read -r target; do
    grep -qF "${target%% *}" "${f}" 2>/dev/null || printf '%s\n' "${target}"
  done < <(rule_imports)
}

rules_name=""; claude_name=""; missing=""
case " ${KEPT_CHAIN} " in
  *" AGENTS.md "*)
    rules_name="$(actual_name AGENTS.md)"; rules_name="${rules_name:-AGENTS.md}"
    missing="$(missing_imports "${rules_name}")"
    [ -n "${missing}" ] || [ "${rules_name}" != "AGENTS.md" ] || rules_name=""
    ;;
esac
case " ${KEPT_CHAIN} " in
  *" CLAUDE.md "*)
    claude_name="$(actual_name CLAUDE.md)"; claude_name="${claude_name:-CLAUDE.md}"
    # In order already: correctly cased, and importing the rules file.
    if [ "${claude_name}" = "CLAUDE.md" ] \
       && grep -q '^@AGENTS\.md[[:space:]]*$' "${REPO}/${claude_name}" 2>/dev/null; then
      claude_name=""
    fi
    ;;
esac

if [ -n "${rules_name}${claude_name}" ]; then
  echo
  echo "NEXT STEPS - bootstrap kept files the project already owned:"
  if [ -n "${rules_name}" ]; then
    if [ -n "${missing}" ]; then
      echo
      echo "  ${rules_name} is yours, so these imports were not added. Put them in it:"
      echo
      printf '%s\n' "${missing}" | sed 's/^/      /'
    fi
    [ "${rules_name}" = "AGENTS.md" ] || {
      echo
      echo "  Rename it to AGENTS.md as well. Windows matches the name whatever its"
      echo "  case, so nothing here complains - but the repository is read on other"
      echo "  machines too. Go through a temporary name so git records the rename:"
      echo "      git mv ${rules_name} tmp.md && git mv tmp.md AGENTS.md"
    }
  fi
  if [ -n "${claude_name}" ]; then
    echo
    echo "  ${claude_name} is yours. It is the one file a session reads by itself,"
    echo "  so it has to import the rules file and nothing else:  @AGENTS.md"
    [ "${claude_name}" = "CLAUDE.md" ] || \
      echo "      git mv ${claude_name} tmp.md && git mv tmp.md CLAUDE.md"
  fi
  echo
  echo "  Until that is done the rule files sit on disk and no session reads them."
fi
exit 0
