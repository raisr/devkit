#!/usr/bin/env bash
# Puts the devkit files into a repository: rules, skills, config and templates.
#
# Run it once when a repository starts, or again to add a stack. It writes
# files and nothing else - no staging, no commit. Review with `git status`.
#
#   d="$(mktemp -d)" \
#     && git clone --depth 1 https://github.com/raisr/devkit "$d/devkit" \
#     && bash "$d/devkit/project/bootstrap.sh" --forge github --stack dotnet
#
# Re-running is safe: managed files are rewritten, blocks are replaced between
# their markers, and templates are left alone once they exist.
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
  --main-branch <name> default branch (default: the current HEAD of the repo)
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
[ -n "${MAIN_BRANCH}" ] || MAIN_BRANCH="$(git -C "${REPO}" symbolic-ref --quiet --short HEAD || echo main)"
[ -n "${ASSIGNEE}" ] || ASSIGNEE="$(git -C "${REPO}" config user.name || echo "")"

DEVKIT_COMMIT="$(git -C "${DEVKIT_ROOT}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
DEVKIT_DATE="$(git -C "${DEVKIT_ROOT}" log -1 --format=%cs 2>/dev/null || echo unknown)"
TODAY="$(date +%F)"

# The solution or workspace file the dotnet gates run against.
SOLUTION="$(cd "${REPO}" && find . -maxdepth 3 \( -name "*.slnx" -o -name "*.sln" \) \
  -not -path "./.git/*" 2>/dev/null | sed "s#^\./##" | sort | head -1)"
[ -n "${SOLUTION}" ] || SOLUTION="TODO-set-the-solution-path"

# Markdown links to the rule files this repository actually received.
STACK_RULE_LINKS=""
for s in ${STACKS[@]+"${STACKS[@]}"}; do
  STACK_RULE_LINKS="${STACK_RULE_LINKS}- [\`AGENTS.${s}.md\`](AGENTS.${s}.md) — rules for the ${s} stack\\n"
done
STACK_RULE_LINKS="${STACK_RULE_LINKS%\\n}"
[ -n "${STACK_RULE_LINKS}" ] || STACK_RULE_LINKS="<!-- no stack pack installed -->"
FORGE_RULE_LINKS="- [\`AGENTS.${FORGE}.md\`](AGENTS.${FORGE}.md) — conventions for ${FORGE}"

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
      -e "s|{{STACK_RULE_LINKS}}|${STACK_RULE_LINKS}|g" \
      -e "s|{{FORGE_RULE_LINKS}}|${FORGE_RULE_LINKS}|g"
}

hash_of() { git hash-object "$1"; }

# The recorded hash is always the hash of the devkit source file, never of what
# ended up in the repository. For a managed file the two are the same, so a
# mismatch means somebody edited it locally. For a block it is the block
# content, which sync compares against what it extracts from the target. For a
# template it is the upstream version the project started from, so sync can say
# that the template moved on without ever touching the file.
LOCK_FILES=""
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
  say managed "$2"
}

apply_template() {   # <src> <target> <origin>
  local src="$1" target="${REPO}/$2" origin="$3"
  if would; then say template "$2"; return; fi
  # An existing template belongs to the project. It still goes into the lock,
  # so a later sync can tell that the upstream template has moved on.
  if [ -e "${target}" ]; then
    record "$2" "${origin}" template "$(hash_of "${src}")"
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

apply_block() {   # <src> <target> <marker id> <origin>
  local src="$1" target="${REPO}/$2" id="$3" origin="$4"
  if would; then say block "$2  [${id}]"; return; fi
  mkdir -p "$(dirname "${target}")"
  [ -e "${target}" ] || : > "${target}"
  BLOCK_SRC="${src}" BLOCK_ID="${id}" awk -f "${DEVKIT_PROJECT_DIR}/block.awk" \
    "${target}" > "${target}.devkit-tmp"
  mv "${target}.devkit-tmp" "${target}"
  record "$2" "${origin}" block "$(hash_of "${src}")" "${id}"
  say block "$2  [${id}]"
}

apply_dir() {   # <src dir> <target dir> <origin>
  local src="$1" target="$2" origin="$3" f rel
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
if [ "${SOLUTION}" = "TODO-set-the-solution-path" ]; then
  echo "Note: no .sln/.slnx found - set SLN in .devkit/gates.sh yourself."
fi
exit 0
