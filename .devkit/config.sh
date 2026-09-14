#!/usr/bin/env bash
# Project settings for the devkit skills and scripts.
#
# This repository is the devkit itself and was never bootstrapped: the file is
# written by hand, and the two keys that name the installed packs mean something
# slightly different here. See AGENTS.md, "Shared rules".
#
# Personal overrides go in .devkit/local.sh, which is git-ignored and sourced
# after this file if it exists.

# Which forge this repository lives on: github | gitlab
DEVKIT_FORGE=github

# Stack packs in use, space separated. Empty on purpose: this repository is
# shell and Markdown, and a stack pack generalised from a single example would
# be a guess. Its own rules live in AGENTS.md until a second such repository
# makes them worth extracting.
DEVKIT_STACKS=""

# full   every change needs a ticket, a branch, a changelog entry, a pull or
#        merge request and a review round
# light  branch and gates only - no ticket, no review round
DEVKIT_WORKFLOW=full

# Default branch, and who gets assigned to a pull request.
DEVKIT_MAIN_BRANCH=main
DEVKIT_ASSIGNEE=raisr

# ask   the drafted commit message is shown and approved before committing
# auto  it is committed as drafted, without asking
DEVKIT_COMMIT_APPROVAL=ask
