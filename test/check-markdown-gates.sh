#!/usr/bin/env bash
# Asserts what the markdown pack's gates.sh reports, each gate both red and
# green.
#
# Usage:  bash test/check-markdown-gates.sh [--out <dir>]
#
# It bootstraps a throwaway repository with --stack markdown rather than
# copying the template into place, so the manifest entry and the installed
# file are exercised too: a gates.sh that never arrives is the failure this
# would otherwise miss.
#
# The repository is committed once after the bootstrap, which makes `git reset
# --hard && git clean -fd` a reliable way back to the green starting point
# between cases.
#
# WHAT THIS CANNOT CHECK: whether the rules in AGENTS.markdown.md are the right
# rules. It checks that the gates enforce what they claim to enforce - wrap
# width, tone and whether a document is worth reading are a review's job, and
# the pack says so.
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVKIT_ROOT="$(cd "${TEST_DIR}/.." && pwd)"

OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT="$2"; shift 2 ;;
    -h|--help) sed -n '2,19p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "${OUT}" ] || OUT="$(mktemp -d)"
mkdir -p "${OUT}"
OUT="$(cd "${OUT}" && pwd)"

REPO="${OUT}/work"
REPORT="${OUT}/gate.txt"

FAILED=0
pass()  { printf '  ok    %s\n' "$1"; }
fail()  { printf '  FAIL  %s\n' "$1"; FAILED=1; }
head2() { printf '\n=== %s ===\n' "$1"; }

export GIT_AUTHOR_NAME="devkit fixture" GIT_AUTHOR_EMAIL="fixture@example.invalid"
export GIT_COMMITTER_NAME="${GIT_AUTHOR_NAME}" GIT_COMMITTER_EMAIL="${GIT_AUTHOR_EMAIL}"

# --- the world ---------------------------------------------------------------

rm -rf "${REPO}"
mkdir -p "${REPO}/docs/guide"
git -C "${REPO}" init -q -b main || { echo "cannot init the sample repo" >&2; exit 1; }

cat > "${REPO}/README.md" <<'EOF'
# Sample

A documentation repository. The [documentation index](docs/README.md) has the
rest.
EOF

cat > "${REPO}/docs/one.md" <<'EOF'
# One

Back to the [index](README.md), and out to [a forge](https://example.invalid).

```bash
# a hash in a code block is a comment, not a heading
echo "[not a link](nowhere.md)"
```

## A section
EOF

cat > "${REPO}/docs/guide/README.md" <<'EOF'
# Guide

| Document | About |
|---|---|
| [`deep.md`](deep.md) | the deep one |
EOF

cat > "${REPO}/docs/guide/deep.md" <<'EOF'
# Deep

## Fine
EOF

bash "${DEVKIT_ROOT}/project/bootstrap.sh" --repo "${REPO}" \
  --forge github --stack markdown --workflow light > /dev/null \
  || { echo "bootstrap failed" >&2; exit 1; }

# bootstrap writes docs/README.md as a template, so the index rows for the two
# documents next to it are added here rather than shipped above.
cat >> "${REPO}/docs/README.md" <<'EOF'

| [`one.md`](one.md) | the first one |
| [`guide/README.md`](guide/README.md) | the guide |
EOF

git -C "${REPO}" add -A
git -C "${REPO}" commit -q -m "the green starting point"

# --- running a gate ----------------------------------------------------------

run_gate() {   # <gate name> - true when it passed
  ( cd "${REPO}" && bash .devkit/gates.sh "$1" ) > "${REPORT}" 2>&1
}

assert_green() {   # <gate> <what>
  if run_gate "$1"; then pass "$2"; else
    fail "$2"
    sed 's/^/        /' "${REPORT}"
  fi
}

assert_red() {   # <gate> <expected substring> <what>
  if run_gate "$1"; then
    fail "$3 — the gate passed"
  elif grep -qF -- "$2" "${REPORT}"; then
    pass "$3"
  else
    fail "$3 — it failed, but not with '$2'"
    sed 's/^/        /' "${REPORT}"
  fi
}

reset_repo() { git -C "${REPO}" reset -q --hard && git -C "${REPO}" clean -qfd; }

# ============================================================================

head2 "the bootstrapped repository is green"

# The regression this exists for: CLAUDE.md is a one-line import stub with no
# H1, so a headings gate that demands one turns every new repository red on the
# day it is created.
assert_green links    "a freshly bootstrapped repository has no broken link"
assert_green index    "and every document is in the index"
assert_green headings "and the import stubs do not count as documents"

head2 "links"

printf '\nA [dead link](nowhere.md).\n' >> "${REPO}/docs/one.md"
assert_red links "link target does not exist: nowhere.md" \
  "a relative link with no file behind it is reported"
reset_repo

printf '\nAn [absent anchor](#nothing-here) and a [mail](mailto:x@example.invalid).\n' \
  >> "${REPO}/docs/one.md"
assert_green links \
  "an anchor and a mailto are not paths and are left alone"
reset_repo

printf '\nSee <https://example.invalid/gone>.\n' >> "${REPO}/docs/one.md"
assert_green links \
  "an external URL is not the gate's business, dead or not"
reset_repo

# The code block in docs/one.md carries `[not a link](nowhere.md)`, which the
# starting point already proves is skipped. This is the other half: the same
# text outside a block is caught.
printf '\n[not a link](nowhere.md)\n' >> "${REPO}/docs/one.md"
assert_red links "link target does not exist: nowhere.md" \
  "the same text outside a code block is caught"
reset_repo

head2 "index"

cat > "${REPO}/docs/two.md" <<'EOF'
# Two

Nobody links here.
EOF
assert_red index "no row for docs/two.md" \
  "a document with no row in the index next to it is reported"

printf '| [`two.md`](two.md) | the second one |\n' >> "${REPO}/docs/README.md"
assert_green index "and adding the row clears it"
reset_repo

mkdir -p "${REPO}/docs/deeper"
cat > "${REPO}/docs/deeper/README.md" <<'EOF'
# Deeper

Nothing points here yet.
EOF
assert_red index "no row for the docs/deeper/ index" \
  "a subdirectory the parent index does not reach is reported"
reset_repo

head2 "headings"

cat > "${REPO}/docs/two.md" <<'EOF'
# Two

# And a second H1
EOF
assert_red headings "a second H1 - this is two documents" \
  "a second H1 is reported"
reset_repo

cat > "${REPO}/docs/two.md" <<'EOF'
# Two

### Straight to H3
EOF
assert_red headings "H1 jumps to H3" \
  "a skipped heading level is reported"
reset_repo

cat > "${REPO}/docs/two.md" <<'EOF'
## Starts too deep
EOF
assert_red headings "starts at H2, not H1" \
  "a document whose first heading is not an H1 is reported"
reset_repo

cat > "${REPO}/docs/two.md" <<'EOF'
Just a paragraph, included from somewhere else.
EOF
assert_green headings \
  "a file with no heading at all is a fragment and is left alone"
reset_repo

cat > "${REPO}/docs/two.md" <<'EOF'
# Two

```bash
# not a heading
## nor this
```

## A real section
EOF
assert_green headings \
  "hashes inside a fenced code block are not headings"
reset_repo

# ============================================================================

printf '\n'
if [ "${FAILED}" -eq 0 ]; then
  echo "MARKDOWN GATES: every assertion held"
else
  echo "MARKDOWN GATES: failed"
fi
exit "${FAILED}"
