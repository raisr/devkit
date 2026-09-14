# Agents.md

A project that already had its own rules before the devkit existed, with the
file named the way Visual Studio's templates name it. Bootstrapping must leave
this file alone: it is a `template` target, and the project owns it.

## Overview

Sample is a fixture. It does nothing and ships nothing.

## Architecture

The dependency arrow points inwards. `Sample.Shell` is the composition root.

## Tests

One test project per production project, under `src/Tests/`.
