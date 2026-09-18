# Extending the devkit

For someone changing devkit itself: a rule, a pack, a skill or the tooling.
Adopting the devkit in a project is a different job and has its own guide,
[`using-devkit.md`](using-devkit.md).

**Every rule is written once, in [`../AGENTS.md`](../AGENTS.md). This document
gives only the order.** Where a step names a rule, follow the link and read it
there — nothing here restates one, because a second copy is the one that goes
stale.

## The gates

```bash
bash .devkit/gates.sh              # all six
bash .devkit/gates.sh manifest     # one of them
```

They run before a commit, not after it and not in CI only
([`core.gates`](../project/core/AGENTS.core.md#gates-coregates)).

| Gate | Proves |
|---|---|
| `syntax` | every tracked `.sh` parses, and `block.awk` is a valid awk program |
| `manifest` | every file under a pack is installed by some `manifest.list` |
| `forge` | both forge adapters expose the same `forge_*` function names |
| `stubs` | `.claude/skills` still matches `project/core/skills` |
| `fixture` | the sample repository bootstraps and every assertion holds |
| `sync` | `collect.sh` reports the right thing in every situation `/devkit-sync` has to judge |

`fixture` builds a repository from scratch and runs `bootstrap.sh` against it
three times, and `sync` builds a second world of its own. Tens of seconds each
is normal, not a hang.

`sync` covers the half of `/devkit-sync` a script can reach. The other half is
a judgement made by reading a diff, and two of its cases have no mechanical
signature at all — `test/README.md` says which, and what a human walks instead.

The gates check what a script can check. For the couplings that need a diff or
a judgement, see [What no gate sees](#what-no-gate-sees) at the end.

## Changing a rule

1. **Check the slug first.** A section heading carries one — `## Async
   {#core.async}` — and consumers record deviations against it. Rewording the
   text beneath a slug is free; renaming or dropping the slug breaks every
   recorded decision that points at it, in repositories you cannot see. See
   [*Rule documents*](../AGENTS.md#rule-documents).
2. Write the rule. Prescriptive voice, no project named.
3. Add a `CHANGELOG.md` entry. It is read by people deciding how to answer a
   `/devkit-sync` question, so say what changed and what it means for them —
   not the commit subject.
4. `bash .devkit/gates.sh`.

A rule that moves between packs is a slug change too: the prefix is part of the
identity. `core.` for `AGENTS.core.md`, the pack name for a stack or shared
pack, and `forge.` for **both** forge packs.

## A new stack pack

```
project/stacks/<name>/
  AGENTS.<name>.md          rules, slugs prefixed <name>.
  manifest.list             what it installs
  editorconfig.block        optional
  gitignore.block           optional
  templates/…               gates.sh and anything the project then owns
```

1. Write `manifest.list`. One line per file, `<source>|<target>|<mode>`, and a
   `+shared/<pack>` line at the top if it builds on a shared pack. Nothing
   reaches a repository without an entry here, and `gate_manifest` fails when a
   file has none.
2. Pick the mode per file, and when in doubt pick `template`. `managed` for
   what devkit keeps owning, `block:<id>` for a list injected between markers,
   `template` for anything carrying a version, a path or a project decision.
   The modes are defined in [*Modes*](../AGENTS.md#modes).
3. Prefix every rule slug with the pack name.
4. Add the pack to the tree in [`../README.md`](../README.md) and to the
   `--stack` row in [`using-devkit.md`](using-devkit.md) — nothing reads those
   tables back, so they go stale silently.
5. Where the pack ships gates of its own, assert them. They are logic this
   repository never runs on itself, because it installs no stack, so
   `gate_syntax` proving they parse is all that stands behind them otherwise.
   Put the assertions in a script under [`../test/`](../test/README.md) and
   wire it into `.devkit/gates.sh` — `stacks/markdown` does it with
   `check-markdown-gates.sh`, driving every gate both red and green.
6. `bash .devkit/gates.sh`.

What two stack packs have in common goes into `project/shared/<name>/` instead,
and is pulled in by a `+shared/<name>` line. A shared pack is deliberately not
selectable with `--stack`: on its own it installs rules without the gates that
enforce them.

## A new forge pack

```
project/forges/<name>/
  AGENTS.<name>.md          slugs prefixed forge. — not <name>.
  forge.sh                  every function the contract defines
  manifest.list
```

The `forge.` prefix is not a mistake: a repository that moves from one forge to
another keeps its recorded deviations pointing at the same rules.

`forge.sh` must define **every** function the other adapters define, or
`gate_forge` fails. Copy the existing adapter and replace the bodies rather
than starting from the command surface.

Then add the pack to the `--forge` row in [`using-devkit.md`](using-devkit.md).

## Extending the forge contract

A skill never names `gh` or `glab`; it calls `forge_*`
([*Forge adapters*](../AGENTS.md#forge-adapters)). So a new function lands in
**every** adapter in the same commit — `gate_forge` compares the names and
fails when only one of them grew.

1. Add the function to `project/forges/github/forge.sh` and
   `project/forges/gitlab/forge.sh`, with the same signature.
2. Take a file path for anything body-shaped. Request and issue bodies are full
   of backticks and do not survive being passed as a string.
3. Name it in the skill that needs it, under `project/core/skills/`.
4. `bash .devkit/gates.sh`.

The GitLab half cannot be proven here — see
[Testing against a real consumer repository](#testing-against-a-real-consumer-repository).

## Changing a skill

The source is `project/core/skills/<name>/`. **`.claude/skills` is generated**
— editing a file there is overwritten without warning by the next run.

```bash
bash .devkit/stubs.sh          # regenerate, after every skill change
```

A new skill also needs its name in `SKILLS` in `.devkit/stubs.sh`, or in
`EXCLUDED` when it deliberately has no stub here. `gate_stubs` fails on a skill
that is in neither, so a skill cannot quietly not exist in this repository.

`maintain` is the exception to all of this: it is local, lives in
`.claude/skills/maintain/` by hand, and is never vendored.

## Changing the tooling

`project/bootstrap.sh`, `project/block.awk` and `project/manifest.sh` are the
three files that are not installed anywhere — they do the installing.

**A change to one of them without a new assertion in
`test/check-sample-repo.sh` counts as unfinished**
([`core.tests`](../project/core/AGENTS.core.md#tests-coretests)). The fixture
is the only test this repository has; `test/README.md` says what it covers and
what it cannot prove.

```bash
r="$(bash test/build-sample-repo.sh)"
bash project/bootstrap.sh --repo "$r" --forge github --stack dotnet-core --workflow full
bash test/check-sample-repo.sh "$r"
```

Assertions use `grep` and `diff`, never "read the output and judge it".

## Testing against a real consumer repository

The fixture proves a bootstrap run. It does not prove that `/devkit-sync`
behaves, and it cannot prove that the rules reach a session at all.

Point the sync collector at a local checkout instead of the published repo:

```bash
bash .claude/skills/devkit-sync/collect.sh /path/to/devkit
```

Run that from the consumer repository, with the devkit path as the argument.
Without one it clones from GitHub and fails loudly rather than working from a
stale copy — so an unpublished change is invisible to it.

Whether the rules actually arrive is answerable only by opening a session in a
bootstrapped repository and asking for something written nowhere but
`AGENTS.core.md`. No script can make that check.

## What no gate sees

```
/maintain
```

A local skill for the couplings that need a diff or a judgement: a renamed rule
slug and what it breaks, a pack missing from the tables in `README.md`,
`docs/README.md` or `using-devkit.md`, a generated file that has fallen behind
its source. It reports, fixes on request, and never commits.

Run it after changing a rule document, a pack or a skill — which is to say
after most of the recipes above.
