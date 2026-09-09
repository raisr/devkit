# AGENTS.md — {{PROJECT_NAME}}

Binding rules for anyone working in this repository, human or agent.
**It prescribes, it does not describe** — explanatory prose belongs in `docs/`,
and this file links to it.

## Shared rules

These files come from [raisr/devkit](https://github.com/raisr/devkit) and are
updated by `/devkit-sync`. Do not edit them here; change them upstream.

- [`AGENTS.core.md`](AGENTS.core.md) — rules that hold in every repository
{{STACK_RULE_LINKS}}
{{FORGE_RULE_LINKS}}

`AGENTS.local.md`, if present next to this file, is read as well and wins on
conflicts. It is personal, machine-specific and git-ignored.

## Overview

<!-- What this project is, in three or four sentences. What it does, who runs
     it, and the one or two facts a newcomer gets wrong without being told. -->

## Tech stack

<!-- Only what binds. The descriptive version belongs in docs/tech-stack.md. -->

## Architecture

<!-- The dependency rules that must not be broken, and what happens when they
     are. The current project layout belongs in docs/architecture.md. -->

## Domain terms

<!-- | Term | Means | — the words this project uses in a specific sense. -->

## Deviations from the shared rules

Rules from `AGENTS.core.md` or a stack pack that deliberately do not apply here.
Every row was decided once and is recorded in `devkit.lock.json`, so
`/devkit-sync` does not ask again until the upstream rule changes.

| Rule | Deviation | Why |
|---|---|---|
| — | none yet | — |
