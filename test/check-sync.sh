#!/usr/bin/env bash
# Asserts what collect.sh reports in each situation /devkit-sync has to judge.
#
# Usage:  bash test/check-sync.sh [--out <dir>]
#
# It builds its own world, because the three hashes only line up when the
# repository was bootstrapped from the same devkit content that is later
# mutated:
#
#   <out>/devkit    a clone of this repository - the "upstream" we can change
#   <out>/work      a sample consumer repository, bootstrapped from that clone
#
# The clone is committed state, so an uncommitted change in the working tree is
# invisible here. That is deliberate: a consumer syncs against what was pushed,
# never against somebody's desk.
#
# WHAT THIS CANNOT CHECK: the judgement. collect.sh decides nothing by design -
# it prints `upstream` and `installed`, and the agent reads devkit.lock.json
# alongside and decides. Two of the five cases have no mechanical signature at
# all:
#
#   - a wording change and a changed rule are the SAME signature, "changed
#     upstream, clean here". What separates them is the content of the diff.
#   - a new core rule that contradicts a project rule matches every hash. It is
#     by definition the case no hash finds.
#
# Those are walked by a human; test/README.md says how. What is asserted below
# is the input every one of those judgements is made from, which is the half a
# script can own.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVKIT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"

OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    -h|--help) sed -n '2,30p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "${OUT}" ] || OUT="$(mktemp -d)"
mkdir -p "${OUT}"
OUT="$(cd "${OUT}" && pwd)"

UPSTREAM="${OUT}/devkit"
COLLECTED="${OUT}/collect.txt"

FAILED=0
pass()  { printf '  ok    %s\n' "$1"; }
fail()  { printf '  FAIL  %s\n' "$1"; FAILED=1; }
head2() { printf '\n=== %s ===\n' "$1"; }

export GIT_AUTHOR_NAME="devkit fixture" GIT_AUTHOR_EMAIL="fixture@example.invalid"
export GIT_COMMITTER_NAME="${GIT_AUTHOR_NAME}" GIT_COMMITTER_EMAIL="${GIT_AUTHOR_EMAIL}"

# --- the world ---------------------------------------------------------------

git clone -q "${DEVKIT_ROOT}" "${UPSTREAM}" || { echo "cannot clone the devkit" >&2; exit 1; }
BASE="$(git -C "${UPSTREAM}" rev-parse HEAD)"

REPO="$(bash "${TEST_DIR}/build-sample-repo.sh" --out "${OUT}/work")" || exit 1
bash "${UPSTREAM}/project/bootstrap.sh" --repo "${REPO}" \
  --forge github --stack dotnet-core --workflow full > /dev/null || exit 1

# The installed files as bootstrap left them, to restore a local edit from.
PRISTINE="${OUT}/pristine"
mkdir -p "${PRISTINE}"
cp "${REPO}/AGENTS.core.md" "${PRISTINE}/AGENTS.core.md"
cp "${REPO}/.editorconfig"  "${PRISTINE}/.editorconfig"

# --- reading the report ------------------------------------------------------

collect() {
  ( cd "${REPO}" && bash .claude/skills/devkit-sync/collect.sh "${UPSTREAM}" ) \
    > "${COLLECTED}" 2>"${OUT}/collect.err"
}

# row_from <pack/source> -> the one line collect.sh printed for it
row_from() { grep -m1 "^$1|" "${COLLECTED}"; }
# row_target <target> <mode> -> a row addressed by target, for orphans
row_target() { grep -m1 "|$1|$2|" "${COLLECTED}"; }
field() { printf '%s\n' "$1" | cut -d'|' -f"$2"; }
upstream_of()  { field "$1" 5; }
installed_of() { field "$1" 6; }

# The hash bootstrap recorded, read out of the lock without jq. `from` is the
# manifest entry, which is unique even where a target appears several times.
lock_hash() {   # <pack/source>
  grep -F "\"from\": \"$1\"" "${REPO}/devkit.lock.json" \
    | sed -n 's/.*"hash": "\([0-9a-f]*\)".*/\1/p' | head -1
}

assert_eq() {   # <actual> <expected> <what>
  if [ "$1" = "$2" ]; then pass "$3"; else fail "$3 (got '$1', wanted '$2')"; fi
}
assert_ne() {   # <actual> <other> <what>
  if [ "$1" != "$2" ]; then pass "$3"; else fail "$3 (both '$1')"; fi
}

# --- mutating the two sides --------------------------------------------------

upstream_reset() { git -C "${UPSTREAM}" reset -q --hard "${BASE}"; }
upstream_commit() { git -C "${UPSTREAM}" add -A && git -C "${UPSTREAM}" commit -q -m "$1"; }
repo_reset() {
  cp "${PRISTINE}/AGENTS.core.md" "${REPO}/AGENTS.core.md"
  cp "${PRISTINE}/.editorconfig"  "${REPO}/.editorconfig"
}

# ============================================================================

head2 "nothing happened"

collect
row="$(row_from core/AGENTS.core.md)"
assert_eq "$(upstream_of "${row}")" "$(installed_of "${row}")" \
  "an untouched managed file reports the same hash on both sides"
assert_eq "$(installed_of "${row}")" "$(lock_hash core/AGENTS.core.md)" \
  "and the lock recorded that same hash"

# The baseline for the two special values further down. Without these, an
# assertion for `no-marker` or `missing` would pass just as happily against a
# collect.sh that printed them for everything.
row="$(row_from core/editorconfig.block)"
assert_eq "$(installed_of "${row}")" "$(upstream_of "${row}")" \
  "an intact block reports its content hash, not no-marker"
assert_ne "$(installed_of "${row}")" "no-marker" \
  "and no-marker is not what an intact block looks like"
row="$(row_from core/templates/CHANGELOG.md)"
assert_eq "$(installed_of "${row}")" "owned" \
  "a template that is present reports owned, not missing"

head2 "changed upstream, clean here"

# A wording change and a changed rule produce this identical signature. The
# assertion is that sync is told the file moved while the repository did not -
# which of the two it is, only a reader of the diff can say.
printf '\nA sentence added upstream, changing nothing that binds.\n' \
  >> "${UPSTREAM}/project/core/AGENTS.core.md"
upstream_commit "wording"
collect
row="$(row_from core/AGENTS.core.md)"
recorded="$(lock_hash core/AGENTS.core.md)"
assert_ne "$(upstream_of "${row}")" "${recorded}" \
  "upstream differs from what was recorded"
assert_eq "$(installed_of "${row}")" "${recorded}" \
  "the installed file still matches what was recorded"
upstream_reset

head2 "edited locally, clean upstream"

printf '\nA line somebody added in the consumer repository.\n' \
  >> "${REPO}/AGENTS.core.md"
collect
row="$(row_from core/AGENTS.core.md)"
recorded="$(lock_hash core/AGENTS.core.md)"
assert_eq "$(upstream_of "${row}")" "${recorded}" \
  "upstream still matches what was recorded"
assert_ne "$(installed_of "${row}")" "${recorded}" \
  "the installed file does not - the local edit is visible"
repo_reset

head2 "changed on both sides"

printf '\nA sentence added upstream.\n' >> "${UPSTREAM}/project/core/AGENTS.core.md"
upstream_commit "both sides"
printf '\nA line added here.\n' >> "${REPO}/AGENTS.core.md"
collect
row="$(row_from core/AGENTS.core.md)"
recorded="$(lock_hash core/AGENTS.core.md)"
assert_ne "$(upstream_of "${row}")"  "${recorded}" "upstream moved"
assert_ne "$(installed_of "${row}")" "${recorded}" "and so did the installed file"
assert_ne "$(upstream_of "${row}")"  "$(installed_of "${row}")" \
  "the two sides disagree with each other as well"
upstream_reset
repo_reset

head2 "a block target that lost its marker"

# Deleting the opening marker must not read as "the block is unchanged", and
# must not read as a hash either: sync has to stop rather than append a second
# block next to whatever is still in there.
grep -v '^# >>> devkit:core >>>$' "${PRISTINE}/.editorconfig" > "${REPO}/.editorconfig"
collect
row="$(row_from core/editorconfig.block)"
assert_eq "$(installed_of "${row}")" "no-marker" \
  "the core editorconfig block reports no-marker"
assert_ne "$(installed_of "${row}")" "$(upstream_of "${row}")" \
  "and is not mistaken for matching content"
repo_reset

head2 "a template that moved on upstream"

printf '\n# A key added upstream after this repository was bootstrapped.\nDEVKIT_NEW_KEY=1\n' \
  >> "${UPSTREAM}/project/core/templates/config.sh"
upstream_commit "template moved"
collect
row="$(row_from core/templates/config.sh)"
assert_eq "$(field "${row}" 3)" "template" "the config template is reported as a template"
assert_eq "$(installed_of "${row}")" "owned" \
  "its installed column reads owned, never a hash"
assert_ne "$(upstream_of "${row}")" "$(lock_hash core/templates/config.sh)" \
  "and the upstream template is visibly no longer the recorded one"
upstream_reset

head2 "a template that is not there at all"

rm -f "${REPO}/CHANGELOG.md"
collect
row="$(row_from core/templates/CHANGELOG.md)"
assert_eq "$(installed_of "${row}")" "missing" \
  "a deleted template reports missing rather than owned"

head2 "a file the devkit does not ship"

collect
row="$(row_target '.claude/skills/house-style/SKILL.md' orphan)"
assert_eq "$(field "${row}" 3)" "orphan" \
  "a skill the project wrote itself is reported as an orphan"
row="$(row_target '.claude/skills/implement-feature/preflight.sh' orphan)"
assert_eq "$(field "${row}" 3)" "orphan" \
  "so is a file the devkit shipped once and dropped"

# ============================================================================

printf '\n'
if [ "${FAILED}" -eq 0 ]; then
  echo "SYNC: every assertion held"
else
  echo "SYNC: failed"
fi
exit "${FAILED}"
