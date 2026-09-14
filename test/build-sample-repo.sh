#!/usr/bin/env bash
# Builds a throwaway repository that looks like a real consumer just before it
# adopts the devkit, so a bootstrap run is exercised against something with the
# properties that actually break it:
#
#   - a real remote, with origin/HEAD pointing at the default branch
#   - checked out on a feature branch, NOT on the default branch
#     (an empty repo on `main` makes the right default branch and the wrong one
#     coincide, which is how the --main-branch bug survived its first test)
#   - a project that already owns Agents.md, Claude.md, .gitignore and
#     .editorconfig, all of which bootstrap must leave alone
#   - a solution file, so the gates template gets a real path substituted
#
# Usage:  bash test/build-sample-repo.sh [--out <dir>]
#         prints the path of the working repository on stdout, nothing else
#
# Nothing here touches the devkit repository itself.
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES="${TEST_DIR}/fixtures"
OUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    -h|--help) sed -n '2,18p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -n "${OUT}" ] || OUT="$(mktemp -d)"
mkdir -p "${OUT}"
OUT="$(cd "${OUT}" && pwd)"

ORIGIN="${OUT}/origin.git"
REPO="${OUT}/sample"
[ -e "${ORIGIN}" ] && { echo "already exists: ${ORIGIN}" >&2; exit 1; }
[ -e "${REPO}" ] && { echo "already exists: ${REPO}" >&2; exit 1; }

# Fixed identity and timestamps, so two runs of this script produce the same
# commit hashes and a diff between two fixtures means a real difference.
export GIT_AUTHOR_NAME="devkit fixture" GIT_AUTHOR_EMAIL="fixture@example.invalid"
export GIT_COMMITTER_NAME="${GIT_AUTHOR_NAME}" GIT_COMMITTER_EMAIL="${GIT_AUTHOR_EMAIL}"
export GIT_AUTHOR_DATE="2026-01-01T00:00:00+00:00"
export GIT_COMMITTER_DATE="${GIT_AUTHOR_DATE}"

git init -q --bare -b main "${ORIGIN}"
git clone -q "${ORIGIN}" "${REPO}" 2>/dev/null

mkdir -p "${REPO}/src/Sample.Shell" "${REPO}/docs"
cp "${FIXTURES}/Agents.md"    "${REPO}/Agents.md"
cp "${FIXTURES}/Claude.md"    "${REPO}/Claude.md"
cp "${FIXTURES}/gitignore"    "${REPO}/.gitignore"
cp "${FIXTURES}/editorconfig" "${REPO}/.editorconfig"
cp "${FIXTURES}/Sample.slnx"  "${REPO}/src/Sample.slnx"
printf 'namespace Sample.Shell\n{\n    public static class Program\n    {\n        public static void Main() { }\n    }\n}\n' \
  > "${REPO}/src/Sample.Shell/Program.cs"

git -C "${REPO}" add -A
git -C "${REPO}" commit -q -m "chore: the state before the devkit"
git -C "${REPO}" push -q origin main
git -C "${REPO}" remote set-head origin -a > /dev/null

# The branch an adoption actually happens on. This is the whole point of the
# fixture: DEVKIT_MAIN_BRANCH must come out as `main`, not as this.
git -C "${REPO}" checkout -q -b feature/42-adopt-devkit

echo "${REPO}"
