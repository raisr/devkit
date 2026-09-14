#!/usr/bin/env bash
# Asserts what a bootstrap run must have produced in the sample repository.
# Everything here is grep or diff, never "read the output and judge it" - the
# point is that two runs on two days reach the same verdict.
#
# Usage:  bash test/check-sample-repo.sh <repo>
#
# Expects <repo> to have been built by build-sample-repo.sh and bootstrapped:
#
#   r="$(bash test/build-sample-repo.sh)"
#   bash project/bootstrap.sh --repo "$r" --forge github --stack dotnet-core \
#        --workflow full
#   bash test/check-sample-repo.sh "$r"
#
# Exit code 0 means every assertion held. WARN lines are not failures: they are
# the steps a bootstrap cannot do for a repository that already owns its rules
# file, and a human still has to.
#
# WHAT THIS CANNOT CHECK: whether the rules actually reach a session. The
# assertions below prove the `@`-import lines are on disk and spelled as
# imports. Whether Claude Code pulls them into context is only answerable by
# opening a real session in the bootstrapped repository and asking for
# something that is only written in AGENTS.core.md. Do that by hand after this
# script is green.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVKIT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"

REPO="${1-}"
[ -n "${REPO}" ] || { echo "usage: check-sample-repo.sh <repo>" >&2; exit 2; }
REPO="$(cd "${REPO}" && pwd)"

FAILED=0
pass() { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; FAILED=1; }
warn() { printf '  warn  %s\n' "$1"; }
head2() { printf '\n=== %s ===\n' "$1"; }

# assert_grep <pattern> <file> <what>
assert_grep() {
  if grep -qF -- "$1" "${REPO}/$2" 2>/dev/null; then pass "$3"; else fail "$3"; fi
}
assert_no_grep() {
  if grep -qF -- "$1" "${REPO}/$2" 2>/dev/null; then fail "$3"; else pass "$3"; fi
}

# --- the bootstrap ran at all ------------------------------------------------

head2 "bootstrap output"
[ -f "${REPO}/devkit.lock.json" ] && pass "devkit.lock.json written" \
  || { fail "devkit.lock.json written"; echo; echo "nothing else can be checked"; exit 1; }

# shellcheck source=/dev/null
DEVKIT_FORGE=""; DEVKIT_STACKS=""; DEVKIT_WORKFLOW=""; DEVKIT_MAIN_BRANCH=""
DEVKIT_COMMIT_APPROVAL=""
. "${REPO}/.devkit/config.sh"

# --- the default branch (the bug this fixture exists for) --------------------

head2 "default branch"
branch="$(git -C "${REPO}" symbolic-ref --quiet --short HEAD)"
[ "${branch}" = "feature/42-adopt-devkit" ] \
  && pass "fixture is on a feature branch (${branch})" \
  || fail "fixture should be on feature/42-adopt-devkit, is on ${branch}"
[ "${DEVKIT_MAIN_BRANCH}" = "main" ] \
  && pass "DEVKIT_MAIN_BRANCH resolved to the remote default (main)" \
  || fail "DEVKIT_MAIN_BRANCH is '${DEVKIT_MAIN_BRANCH}', expected main"

# --- config keys -------------------------------------------------------------

head2 "config"
[ -n "${DEVKIT_COMMIT_APPROVAL}" ] \
  && pass "DEVKIT_COMMIT_APPROVAL present (${DEVKIT_COMMIT_APPROVAL})" \
  || fail "DEVKIT_COMMIT_APPROVAL missing from .devkit/config.sh"
# Not just "a solution": the right one. The fixture plants a decoy under .vs/,
# which is what a Windows machine really looks like and sorts first.
assert_grep 'SLN="src/Sample.slnx"' .devkit/gates.sh \
  "gates.sh points at src/Sample.slnx, not the .vs/ copy"

# --- blocks ------------------------------------------------------------------

check_blocks() {   # <file>
  local f="$1" opens closes id
  opens="$(grep -c '^# >>> devkit:' "${REPO}/${f}" 2>/dev/null || echo 0)"
  closes="$(grep -c '^# <<< devkit:' "${REPO}/${f}" 2>/dev/null || echo 0)"
  if [ "${opens}" -gt 0 ] && [ "${opens}" -eq "${closes}" ]; then
    pass "${f}: ${opens} block(s), every marker closed"
  else
    fail "${f}: ${opens} opening and ${closes} closing markers"
  fi
  # No marker id twice - that is what a duplicated block looks like.
  if [ "$(grep '^# >>> devkit:' "${REPO}/${f}" | sort | uniq -d | wc -l)" -eq 0 ]; then
    pass "${f}: no duplicated block"
  else
    fail "${f}: a block id appears more than once"
  fi
}

head2 "blocks"
check_blocks .editorconfig
check_blocks .gitignore
assert_grep '# >>> devkit:core >>>'          .gitignore     "core block installed"
assert_grep '# >>> devkit:shared/dotnet >>>' .gitignore     "shared/dotnet block installed"
assert_grep '# >>> devkit:shared/dotnet >>>' .editorconfig  "shared/dotnet editorconfig block installed"

# --- what the project owns must survive --------------------------------------

head2 "project-owned content"
assert_grep '/sample-data/'      .gitignore    ".gitignore keeps /sample-data/"
assert_grep '*.local.env'        .gitignore    ".gitignore keeps *.local.env"
assert_grep '!keep-me.local.env' .gitignore    ".gitignore keeps the negation"
assert_grep '[*.fixture]'        .editorconfig ".editorconfig keeps [*.fixture]"
assert_grep 'indent_size = 7'    .editorconfig ".editorconfig keeps indent_size = 7"

# A project line that ended up inside a devkit block would be rewritten by the
# next sync, so being present is not enough - it has to be outside.
outside_blocks() {   # <file> <literal line>
  awk -v want="$2" '
    /^# >>> devkit:/ { inside = 1; next }
    /^# <<< devkit:/ { inside = 0; next }
    index($0, want) && !inside { found = 1 }
    END { exit(found ? 0 : 1) }
  ' "${REPO}/$1"
}
outside_blocks .gitignore '/sample-data/' \
  && pass "project .gitignore lines are outside the devkit blocks" \
  || fail "project .gitignore lines ended up inside a devkit block"
outside_blocks .editorconfig '[*.fixture]' \
  && pass "project .editorconfig lines are outside the devkit blocks" \
  || fail "project .editorconfig lines ended up inside a devkit block"

# ...and below them. Both formats let the later line win - an .editorconfig
# section overrides an earlier one, a .gitignore negation re-includes - so a
# block sitting underneath the project's own lines would quietly override them.
blocks_come_first() {   # <file> <literal project line>
  local blk prj
  blk="$(grep -n '^# >>> devkit:' "${REPO}/$1" | head -1 | cut -d: -f1)"
  prj="$(grep -nF -- "$2" "${REPO}/$1" | head -1 | cut -d: -f1)"
  [ -n "${blk}" ] && [ -n "${prj}" ] && [ "${blk}" -lt "${prj}" ]
}
blocks_come_first .gitignore '/sample-data/' \
  && pass "devkit blocks come before the project's .gitignore lines" \
  || fail "devkit blocks sit below the project's .gitignore lines"
blocks_come_first .editorconfig '[*.fixture]' \
  && pass "devkit blocks come before the project's .editorconfig lines" \
  || fail "devkit blocks sit below the project's .editorconfig lines"

# root = true only means anything in the preamble, before the first section.
if [ -f "${REPO}/.editorconfig" ]; then
  first_section="$(grep -n '^\[' "${REPO}/.editorconfig" | head -1 | cut -d: -f1)"
  first_root="$(grep -n '^root[[:space:]]*=' "${REPO}/.editorconfig" | head -1 | cut -d: -f1)"
  if [ -n "${first_root}" ] && { [ -z "${first_section}" ] || [ "${first_root}" -lt "${first_section}" ]; }; then
    pass ".editorconfig declares root before the first section"
  else
    fail ".editorconfig has no root declaration in its preamble"
  fi
fi

# --- templates the project already had must not be rewritten -----------------

head2 "templates left alone"
assert_grep 'A project that already had its own rules' Agents.md \
  "the project's own Agents.md is untouched"

# --- the import chain --------------------------------------------------------
#
# This is the regression guard for the defect where the rule files were linked
# as Markdown instead of imported, and therefore never loaded.

head2 "import chain"
entry=""
for c in CLAUDE.md Claude.md claude.md; do
  [ -f "${REPO}/${c}" ] && { entry="${c}"; break; }
done
if [ -z "${entry}" ]; then
  fail "no CLAUDE.md - nothing imports anything"
else
  pass "entry file present (${entry})"
  grep -q '^@' "${REPO}/${entry}" \
    && pass "${entry} starts an import chain" \
    || fail "${entry} contains no @ import"
fi

# Every managed rule file that landed in the repository has to be imported from
# the project's rules file, spelled as an import and not as a link.
rules_file=""
for c in AGENTS.md Agents.md agents.md; do
  [ -f "${REPO}/${c}" ] && { rules_file="${c}"; break; }
done
missing=""
for f in "${REPO}"/AGENTS.*.md; do
  [ -f "${f}" ] || continue
  n="$(basename "${f}")"
  [ "${n}" = "AGENTS.local.md" ] && continue
  if [ -n "${rules_file}" ] && grep -qF "@${n}" "${REPO}/${rules_file}"; then
    pass "${n} is imported from ${rules_file}"
  else
    missing="${missing}@${n}
"
  fi
  # The exact shape of the original defect.
  if [ -n "${rules_file}" ] && grep -qF "](${n})" "${REPO}/${rules_file}"; then
    fail "${n} is linked as Markdown in ${rules_file} - a link is never followed"
  fi
done

if [ -n "${missing}" ]; then
  if grep -q '{{' "${REPO}/${rules_file}" 2>/dev/null; then
    fail "${rules_file} still holds unsubstituted placeholders"
  else
    warn "${rules_file} belongs to the project, so bootstrap left it alone."
    warn "These imports are not in it and a human has to add them:"
    printf '%s' "${missing}" | sed 's/^/          /'
  fi
fi

# --- skills ------------------------------------------------------------------

head2 "skills"
for s in commit-message create-issue devkit-sync implement-feature; do
  [ -f "${REPO}/.claude/skills/${s}/SKILL.md" ] \
    && pass "skill ${s} installed" || fail "skill ${s} missing"
done

# A dir target is copied into, never emptied. Bootstrap reports what the devkit
# no longer ships, but deleting is the project's decision - so both of these
# have to survive, whatever the report says about them.
[ -f "${REPO}/.claude/skills/implement-feature/preflight.sh" ] \
  && pass "a dropped devkit file is left in place, not deleted" \
  || fail "bootstrap deleted a file the devkit no longer ships"
[ -f "${REPO}/.claude/skills/house-style/SKILL.md" ] \
  && pass "the project's own skill survives" \
  || fail "bootstrap deleted a skill the project wrote itself"

# --- a second run changes nothing -------------------------------------------

head2 "idempotency"
snapshot() {
  ( cd "${REPO}" && find . -type f -not -path './.git/*' -not -name 'devkit.lock.json' \
      | sort | while IFS= read -r f; do printf '%s %s\n' "$(git hash-object "${f}")" "${f}"; done )
}
before="$(snapshot)"
if bash "${DEVKIT_ROOT}/project/bootstrap.sh" --repo "${REPO}" \
     --forge "${DEVKIT_FORGE}" ${DEVKIT_STACKS:+$(printf -- '--stack %s ' ${DEVKIT_STACKS})} \
     --workflow "${DEVKIT_WORKFLOW}" > /dev/null 2>&1; then
  after="$(snapshot)"
  if [ "${before}" = "${after}" ]; then
    pass "a second bootstrap run changes no file"
  else
    fail "a second bootstrap run changed files:"
    diff <(printf '%s\n' "${before}") <(printf '%s\n' "${after}") | sed 's/^/          /'
  fi
else
  fail "a second bootstrap run failed outright"
fi

# --- adding a stack later ----------------------------------------------------
#
# .devkit/config.sh is a template and is never overwritten, but DEVKIT_STACKS is
# not a project decision: collect.sh reads it to work out which files
# /devkit-sync compares, so a stale value does not merely misinform - it makes
# the new stack invisible to the sync. The re-run below therefore also passes
# --workflow light, to prove the carve-out stops at the two pack keys and leaves
# the fixture's `full` alone.
#
# This is last because it leaves the sample repository on two stacks.

head2 "adding a stack later"
if bash "${DEVKIT_ROOT}/project/bootstrap.sh" --repo "${REPO}" \
     --forge "${DEVKIT_FORGE}" --stack dotnet-core --stack dotnet-legacy \
     --workflow light > /dev/null 2>&1; then
  stacks="$(sed -n 's/^DEVKIT_STACKS=//p' "${REPO}/.devkit/config.sh" | tr -d '"')"
  both=1
  case " ${stacks} " in *" dotnet-core "*) ;; *) both=0 ;; esac
  case " ${stacks} " in *" dotnet-legacy "*) ;; *) both=0 ;; esac
  [ "${both}" -eq 1 ] \
    && pass "DEVKIT_STACKS lists both stacks (${stacks})" \
    || fail "DEVKIT_STACKS is '${stacks}', expected both stacks"
  [ -f "${REPO}/AGENTS.dotnet-legacy.md" ] \
    && pass "the added stack's rule file is installed" \
    || fail "AGENTS.dotnet-legacy.md missing after adding the stack"
  assert_grep 'DEVKIT_WORKFLOW=full' .devkit/config.sh \
    "a project decision (workflow) survives the re-run"
  assert_grep 'DEVKIT_COMMIT_APPROVAL' .devkit/config.sh \
    "the rest of config.sh survives the key update"
else
  fail "a re-run with a second stack failed outright"
fi

# --- verdict -----------------------------------------------------------------

echo
if [ "${FAILED}" -eq 0 ]; then
  echo "SAMPLE REPO: all assertions held"
  echo "Still unproven by this script: whether a session actually loads the"
  echo "imported rules. Open Claude Code in ${REPO} and ask for something that"
  echo "only AGENTS.core.md says."
else
  echo "SAMPLE REPO: assertions failed"
fi
exit "${FAILED}"
