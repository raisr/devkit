#!/usr/bin/env bash
# Project settings for the devkit skills and scripts.
# This file belongs to the project - devkit-sync never overwrites it.
#
# Personal overrides go in .devkit/local.sh, which is git-ignored and sourced
# after this file if it exists.

# Which forge this repository lives on: github | gitlab
DEVKIT_FORGE={{FORGE}}

# Stack packs in use, space separated.
DEVKIT_STACKS="{{STACKS}}"

# full   every change needs a ticket, a branch, a changelog entry, a pull or
#        merge request and a review round
# light  branch and gates only - no ticket, no review round
DEVKIT_WORKFLOW={{WORKFLOW}}

# Default branch, and who gets assigned to a pull or merge request.
DEVKIT_MAIN_BRANCH={{MAIN_BRANCH}}
DEVKIT_ASSIGNEE={{ASSIGNEE}}

# ask   the drafted commit message is shown and approved before committing
# auto  it is committed as drafted, without asking
#
# The commit message is the only text an agent produces that goes out under a
# human name without saying so - core.signature exempts commit messages - and
# published history is never rewritten. Start on `ask`; move to `auto` once the
# messages this repository produces have earned it.
DEVKIT_COMMIT_APPROVAL=ask
