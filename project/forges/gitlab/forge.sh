#!/usr/bin/env bash
# GitLab implementation of the forge contract. Managed by devkit-sync -
# edit it upstream in raisr/devkit, not here.
#
# Every forge pack defines the same function names, so the skills never
# mention gh or glab. Sourced, not executed.
#
# STATUS: not yet exercised against a real project. It is written from the
# glab command surface, not from a run. The first repository that bootstraps
# with --forge gitlab verifies it, function by function, and fixes what is
# wrong here. Until then, treat a failure as a bug in this file rather than
# in the skill that called it.

forge_name()      { echo "gitlab"; }
forge_pr_term()   { echo "merge request"; }
forge_pr_short()  { echo "MR"; }

forge_check() {
  glab auth status >/dev/null 2>&1 || { echo "glab is not authenticated" >&2; return 1; }
  glab repo view 2>/dev/null | sed -n '1p'
}

# forge_labels_list -> one label name per line
forge_labels_list() {
  glab label list --output json --jq '.[].name'
}

# forge_label_create <name> <hex colour without #> <description>
forge_label_create() {
  glab label create --name "$1" --color "#$2" --description "$3"
}

forge_issue_list_open() {
  glab issue list
}

# forge_issue_create <title> <label> <body file> [assignee] -> issue URL
# The assignee is left off when it is empty, so the issue stays unassigned.
forge_issue_create() {
  glab issue create --title "$1" --label "$2" --description "$(cat "$3")" \
    ${4:+--assignee "$4"} --yes
}

forge_issue_view() {
  glab issue view "$1"
}

# forge_issue_reply <number> <body file> - where a finding made while working
# the ticket goes (forge.issues), rather than into the description. A file, not
# a string: the note names files and rules, so it is full of backticks.
forge_issue_reply() {
  glab issue note "$1" --message "$(cat "$2")"
}

# forge_issue_body <number> -> raw body. Read from JSON, not cut out of the
# text view: implement-feature writes it back through forge_issue_edit, so it
# must be the stored description byte for byte.
forge_issue_body() {
  glab issue view "$1" --output json --jq .description
}

# forge_issue_milestone <number> -> milestone title, or nothing when it has none
forge_issue_milestone() {
  glab issue view "$1" --output json --jq '.milestone.title // empty'
}

# forge_issue_edit <number> <body file> - replaces the whole description. For a
# ticket that was wrong when it was filed, before work starts, and for ticking
# its Definition of Done after the merge (forge.review); a finding made while
# working it goes into forge_issue_reply instead (forge.issues).
forge_issue_edit() {
  glab issue update "$1" --description "$(cat "$2")"
}

# forge_pr_create <base> <head> <title> <label> <assignee> <body file>
#   [milestone] -> URL
# The milestone is left off when it is empty, so a request whose issue has
# none is created without one.
forge_pr_create() {
  glab mr create --target-branch "$1" --source-branch "$2" --title "$3" \
    --label "$4" --assignee "$5" --description "$(cat "$6")" \
    ${7:+--milestone "$7"} --yes
}

forge_pr_view() {
  glab mr view "$1"
}

forge_pr_comments() {
  glab mr view "$1" --comments
}

# GitLab reports line comments in the same stream as the discussion.
forge_pr_line_comments() {
  glab mr view "$1" --comments
}

forge_pr_assign() {
  glab mr update "$1" --assignee "$2"
}

# forge_pr_edit <number> <body file> - replaces the whole description
forge_pr_edit() {
  glab mr update "$1" --description "$(cat "$2")"
}

# forge_pr_reply <number> <body file> - a comment on the request itself, which
# is what forge.review asks a review round to end with. A file, not a string:
# the reply names commits and rules, so it is full of backticks.
forge_pr_reply() {
  glab mr note "$1" --message "$(cat "$2")"
}
