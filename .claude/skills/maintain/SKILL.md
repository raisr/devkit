---
name: maintain
description: Check this repository for the couplings a gate cannot see - renamed rule slugs, packs missing from the README and docs tables, stale generated files - and fix them on request. Use when asked to "maintain", "check the repo", "did I forget anything", "is everything consistent", or after changing a rule document, a pack or a skill.
---

# maintain

devkit's product is other repositories, and several of its files only make sense
together. `.devkit/gates.sh` enforces the couplings a script can check. This
skill takes the rest — the ones that need a diff, a judgement, or both — and
fixes them when the user says so.

It is local to this repository. It is **not** under `project/` and is never
vendored: manifests, packs and forge adapters are concepts no consumer has.

It writes files. It never stages and never commits.

Paths below are relative to the repository root.

## 1. Run the gates first

```bash
bash .devkit/gates.sh
```

Anything red there is mechanical and already named precisely. Report it, offer
the fix, and do not re-derive it by hand:

| Gate | Fix |
|---|---|
| `stubs` | `bash .devkit/stubs.sh`, or add the new skill to `SKILLS`/`EXCLUDED` in `.devkit/stubs.sh` first |
| `manifest` | add the file to its pack's `manifest.list` — or decide it is tooling and belongs in the allowlist in `gate_manifest` |
| `forge` | add the missing function to the other adapter, in this same change (`AGENTS.md`, *Forge adapters*) |
| `syntax`, `fixture`, `sync` | an ordinary defect; fix it |

## 2. Renamed or dropped rule slugs

A section slug is the identity of a rule. Consumers record deviations against
it, so renaming one breaks every recorded decision that points at it, in
repositories nobody here can see.

```bash
git diff HEAD -- '*AGENTS*.md' | grep -E '^[-+].*\{#'
```

A slug that disappears on the `-` side and does not reappear on the `+` side is
a **breaking change**. Say so plainly, and put the three options to the user:
keep the old slug, rename deliberately and note it in the changelog, or split
the rule so the old slug survives.

A slug moving between packs — `core.design` becoming `dotnet.design` — is the
same thing. The prefix is part of the identity.

## 3. What the tables say versus what exists

These go stale silently, because nothing reads them back:

- `README.md` — the pack tree, the flag table, the *What lands in a repository*
  table, the *Status* section
- `docs/README.md` — one line per document, and every document present
- `docs/using-devkit.md` — the file/mode table and the worked examples
- `AGENTS.md` — the *Modes* list, the *Deviations* table
- `test/README.md` — what the fixture asserts

Read them against the current state of `project/` and the scripts. A new pack, a
new mode, a new flag or a changed default that is not in these is a
documentation defect (`core.docs`), not a follow-up ticket.

## 4. The two files that are generated

`.claude/skills/*/SKILL.md` and the `*.sh` shims next to them come from
`.devkit/stubs.sh`. Never edit them by hand — the next run silently overwrites
the edit. If a stub needs different wording, the generator is what changes.

## 5. Report

- what the gates found, and what you fixed
- every slug change, with its consequence spelled out
- every table that no longer matches
- what you deliberately did not touch, and why

Then stop. The commit is the user's.

## Gotchas

- `gate_fixture` builds a sample repository and runs bootstrap three times. Tens
  of seconds is normal, not a hang.
- The fixture is the only test this repository has. A change to `bootstrap.sh`,
  `block.awk` or `manifest.sh` without a new assertion in
  `test/check-sample-repo.sh` counts as unfinished (`core.tests`).
- `.devkit/config.sh` here is hand-written, not bootstrapped. `DEVKIT_STACKS` is
  empty on purpose — do not "fix" it.
