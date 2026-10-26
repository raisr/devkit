#!/usr/bin/env bash
# GitLab implementation of the forge contract. Managed by devkit-sync -
# edit it upstream in raisr/devkit, not here.
#
# Every forge pack defines the same function names, so the skills never
# mention gh or glab. Sourced, not executed.
#
# STATUS: exercised function by function against sample repositories on
# gitlab.com, with glab 1.117.0. Every query reads glab's JSON output
# (--output json --jq), which an older glab may not offer. Treat a failure as a
# bug in this file rather than in the skill that called it, and fix it here.

forge_name()      { echo "gitlab"; }
forge_pr_term()   { echo "merge request"; }
forge_pr_short()  { echo "MR"; }

# Is the CLI there and authenticated, and which repository does it point at?
forge_check() {
  glab auth status >/dev/null 2>&1 || { echo "glab is not authenticated" >&2; return 1; }
  glab repo view --output json --jq .path_with_namespace
}

# forge_labels_list -> one label name per line
forge_labels_list() {
  glab label list --output json --jq '.[].name'
}

# forge_label_create <name> <hex colour without #> <description>
forge_label_create() {
  glab label create --name "$1" --color "#$2" --description "$3"
}

# forge_issue_list_open -> "<number>|<labels, comma separated>|<title>"
forge_issue_list_open() {
  glab issue list --output json \
    --jq '.[] | "\(.iid)|\(.labels | join(","))|\(.title)"'
}

# forge_issue_create <title> <label> <body file> [assignee] -> issue URL
# The assignee is left off when it is empty, so the issue stays unassigned.
forge_issue_create() {
  glab issue create --title "$1" --label "$2" --description "$(cat "$3")" \
    ${4:+--assignee "$4"} --yes
}

# forge_issue_view <number> -> "#<n> [<state>] <title>   labels=<a,b>"
forge_issue_view() {
  glab issue view "$1" --output json \
    --jq '"#\(.iid) [\(.state)] \(.title)   labels=\(.labels | join(","))"'
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

# forge_issue_block <number> <blocker> - records that <number> is blocked by
# <blocker>, as an issue link of type is_blocked_by. <blocker> is an iid in this
# project or <group>/<project>#<iid> in another one.
#
# Blocking links need a paid tier. On the free tier the link is made as
# relates_to instead, the downgrade is said on stderr, and the function returns
# 2 - so the caller can tell a real block from a mere reference.
forge_issue_block() {
  local project="" blocker="$2" pid out
  case "$2" in *'#'*) project="${2%#*}"; blocker="${2##*#}" ;; esac
  pid="$(glab repo view ${project:+"${project}"} --output json --jq .id)" || return 1
  out="$(glab api -X POST "projects/:id/issues/$1/links" -f target_project_id="${pid}" \
    -f target_issue_iid="${blocker}" -f link_type=is_blocked_by 2>&1)" && return 0
  case "${out}" in
    *'not available for current license'*) ;;
    *) printf '%s\n' "${out}" >&2; return 1 ;;
  esac
  echo "gitlab: blocking links need a paid tier - linked as related instead" >&2
  glab api -X POST "projects/:id/issues/$1/links" -f target_project_id="${pid}" \
    -f target_issue_iid="${blocker}" -f link_type=relates_to > /dev/null || return 1
  return 2
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

# forge_pr_view <branch or number> -> "#<n> state=<s> draft=<b> review=<r>\n<url>"
# GitLab has no review decision. review= is its detailed merge status instead:
# not_approved while an approval is missing, and it also reports failing CI and
# conflicts, so read it as "what still blocks the merge".
forge_pr_view() {
  glab mr view "$1" --output json \
    --jq '"#\(.iid) state=\(.state) draft=\(.draft) review=\(.detailed_merge_status)\n\(.web_url)"'
}

# forge_pr_comments <number> -> the human comments, one block each. System
# notes are left out, and so are comments on a diff line, which
# forge_pr_line_comments reports - the same split the GitHub adapter makes.
forge_pr_comments() {
  glab mr view "$1" --comments --output json --jq '.Discussions[].notes[]
    | select((.system | not) and .position == null) | .body'
}

# forge_pr_line_comments <number> -> "<path>:<line>  <body>"
# GitLab reports line comments in the same stream as the discussion; the ones
# on a diff line are the notes that carry a position. A comment on a removed
# line has only an old line number.
forge_pr_line_comments() {
  glab mr view "$1" --comments --output json --jq '.Discussions[].notes[]
    | select(.position != null)
    | "\(.position.new_path):\(.position.new_line // .position.old_line)  \(.body)"'
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
