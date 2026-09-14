#!/usr/bin/env bash
# The forge contract, as the skills expect to find it.
#
# A consumer repository receives a copy of the adapter here. This repository is
# the devkit itself, so it sources the original instead - one truth, and no copy
# that can fall behind the pack it came from.
#
# This repository is on GitHub; the adapter is picked to match DEVKIT_FORGE in
# .devkit/config.sh. Sourced, not executed.

. "$(git rev-parse --show-toplevel)/project/forges/github/forge.sh"
