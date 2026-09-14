# devkit

Shared development rules, agent skills and project scaffolding, kept in one
place and copied into the repositories that use them.

Nothing here is a runtime dependency. A repository that has been bootstrapped
carries **real files**: the rule documents, the skills, the config. Clone that
repository without this one and everything is still there, readable by anyone,
with or without an agent.

## The areas

| Area | What it is | Who reads it |
|---|---|---|
| `project/` | Everything that gets copied **into a repository**: rules, skills, editor and ignore settings, templates | `bootstrap.sh` and the `devkit-sync` skill |
| `machine/` | Everything that sets up a **development machine**: tools, git configuration, folder layout | you, by hand |
| `test/` | A sample consumer repository and the assertions a bootstrap run has to satisfy | you, before changing anything in `project/` |

The sync tooling only ever looks below `project/`. The other two can grow to
any size without a chance of them leaking into a project repository.

## Packs

`project/` is cut along the two axes that actually differ between projects:

```
project/
  core/                  rules that hold everywhere, the skills, the templates
  shared/dotnet/         .NET rules that hold whatever the runtime
  stacks/dotnet-core/    net5+: compiler, style, logging, config, dotnet gates
  stacks/dotnet-legacy/  .NET Framework: MSBuild gates, C# 7.3 language rules
  forges/github/         branch, commit, issue and pull request conventions + gh adapter
  forges/gitlab/         the same, for GitLab + glab adapter
```

A repository picks one forge and any number of stacks. Each pack declares what
it installs in its own `manifest.list`; `project/manifest.sh` reads them.

`shared/` is not pickable. It holds what two stack packs have in common, and a
stack pack pulls it in with a `+shared/<name>` line at the top of its manifest
— `--stack dotnet-core` installs `shared/dotnet` with it. On its own a shared
pack would deliver rules without the gates that enforce them, so `--stack
dotnet` is refused rather than half-installed.

## Bootstrapping a repository

Run this **inside the repository you want to set up**. It needs `git` and
nothing else — no agent, no account, no `jq`:

```bash
d="$(mktemp -d)" \
  && git clone --depth 1 https://github.com/raisr/devkit "$d/devkit" \
  && bash "$d/devkit/project/bootstrap.sh" --forge github --stack dotnet-core
```

Under Git Bash on Windows, use `mktemp -d` as shown — `$TEMP` holds a path with
backslashes that `bash` does not resolve.

| Flag | |
|---|---|
| `--forge github\|gitlab` | required |
| `--stack <name>` | repeat it for a repository with more than one stack |
| `--workflow full\|light` | default `light`; see *Workflow* below |
| `--assignee <name>` | who gets assigned to a pull or merge request; defaults to `git config user.name` |
| `--main-branch <name>` | defaults to the default branch `origin` points at; only a repository without a remote falls back to the current branch, with a warning when that is not `main`/`master` |
| `--repo <path>` | set up a different repository than the current one |
| `--dry-run` | print what would happen, write nothing |

The script writes files and nothing else. No staging, no commit — review it
with `git status` and commit it yourself.

Running it again is safe, and is how a repository picks up a second stack:
managed files are rewritten, blocks are replaced between their markers, and
anything the project owns is left alone.

## Workflow

`DEVKIT_WORKFLOW` in `.devkit/config.sh` decides how much ceremony a change
carries. The skills read it; changing it is one line, and a deliberate one.

**`full`** — for a repository with a team, or one that is past its opening
phase:

1. A ticket exists. No ticket, no code.
2. Branch from an up-to-date default branch: `feature/<ticket>-<slug>`, or
   `fix/<ticket>-<slug>`.
3. Implement in small, reviewable steps. New or changed logic without a test
   counts as unfinished.
4. A user-visible change gets a `CHANGELOG.md` entry under `[Unreleased]`.
5. `bash .devkit/gates.sh` — all green.
6. Commit, with the ticket number parsed out of the branch name.
7. Open a pull or merge request: what changed, why, and the gate output.
8. Review round: address every point, re-run the gates, push, reply.
9. Done when the request is merged — not when the gates pass.

**`light`** — for a greenfield repository, a spike, or a solo phase: branch,
gates, commit. No ticket, no request, no review round. Everything else still
applies: the rules bind, the tests bind, the gates bind.

Both modes run the same gates and obey the same rules. The mode changes who
has to agree, not what is allowed.

## What lands in a repository

| File | Mode | Meaning |
|---|---|---|
| `AGENTS.core.md`, `AGENTS.<stack>.md`, `AGENTS.<forge>.md` | managed | replaced by `devkit-sync`; edit them here, not there |
| `.claude/skills/**` | managed | the skills, forge-neutral |
| `.devkit/forge.sh` | managed | `gh` or `glab` behind one set of function names |
| `.gitattributes` | managed | line endings |
| `.editorconfig`, `.gitignore` | block | devkit content between markers, project content below |
| `CLAUDE.md` | template | one line, `@AGENTS.md` — the entry point Claude Code actually reads |
| `AGENTS.md` | template | **the project owns it**; `@`-imports the managed rules, records deviations |
| `AGENTS.local.md` | template | personal, git-ignored; seeded from `~/.claude/AGENTS.local.md` if you keep one |
| `.devkit/config.sh`, `.devkit/gates.sh` | template | project owns them: forge, workflow, build commands |
| `CHANGELOG.md`, `ROADMAP.md`, `docs/README.md` | template | written once if missing |
| `devkit.lock.json` | — | where the files came from, at which commit, plus the deviations |

*managed* is replaced on sync, *block* is replaced between its markers, and
*template* is written once and never touched again.

The rules reach a session through one chain of `@`-imports: `CLAUDE.md` →
`AGENTS.md` → `AGENTS.core.md`, the stack file, the forge file and
`AGENTS.local.md`. Those are imports, not Markdown links. A link is never
followed into context, so turning one of them into a link switches the rules
off with nothing to see. An import whose file is missing is ignored, which is
why `AGENTS.local.md` can stay git-ignored.

## Updating a repository

`/devkit-sync` in that repository. It clones this repo, compares what it finds
against the vendored files **and** against the project rules in `AGENTS.md`,
then splits the result:

- text-only changes to files nobody touched locally are applied and shown in
  one diff
- a changed rule, a locally edited file, or a new rule that contradicts the
  project is put to you as a question, one at a time, with a recommendation

Decisions are recorded twice: readable in the *Deviations* table of the
project `AGENTS.md`, machine-readable in `devkit.lock.json` together with the
devkit commit they were decided against. The same question is asked again only
when that rule changes upstream.

Nothing is committed. You review the diff.

## Changing a rule

This is an ordinary repository. Clone it, change the rule, commit, push.
Repositories pick the change up at their next `/devkit-sync`. There are no
releases and no tags: `main` is the truth, and a lock file records the commit.

## Documentation

[docs/README.md](docs/README.md) lists what is written down and where. Start
with [docs/handover.md](docs/handover.md) — it carries the decisions behind
the design and the open work.

## Status

In use, not yet proven in anger.

- Bootstrap, manifests and the block mechanism work. `test/build-sample-repo.sh`
  builds a fixture that looks like a real consumer and
  `test/check-sample-repo.sh` asserts the result; see *Testing a change here*
  in [docs/handover.md](docs/handover.md).
- The core, shared .NET, `dotnet-core` and GitHub rule documents are written and
  in use.
- The four skills are written; `devkit-sync` has been exercised against a test
  repository, the forge-facing ones have not been run against a live project.
- **Written but never executed:** the GitLab adapter (from the `glab` command
  surface) and the `dotnet-legacy` pack (from the MSBuild, NuGet and VSTest
  command surface). The first project that uses either is what verifies it.
