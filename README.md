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

## Getting it into a repository

Run this **inside the repository you want to set up**. It needs `git` and
nothing else — no agent, no account, no `jq`:

```bash
d="$(mktemp -d)" \
  && git clone --depth 1 https://github.com/raisr/devkit "$d/devkit" \
  && bash "$d/devkit/project/bootstrap.sh" --forge github --stack dotnet-core
```

It writes files and nothing else: no staging, no commit — review it with
`git status` and commit it yourself. The flags, what lands in the repository
and in which mode, the two workflow modes, and how a repository picks up later
changes with `/devkit-sync` are all in
[docs/using-devkit.md](docs/using-devkit.md).

## Documentation

| Where | For whom |
|---|---|
| [docs/using-devkit.md](docs/using-devkit.md) | a project adopting the devkit |
| [docs/extending-devkit.md](docs/extending-devkit.md) | someone changing the devkit itself |
| [AGENTS.md](AGENTS.md) | the binding rules for working in this repository |
| [CHANGELOG.md](CHANGELOG.md) | what changed, for the people who vendor it |

Beyond those, the reasoning lives next to what it governs rather than in one
document that goes stale: each rule document states its own rules, and the
comments in `bootstrap.sh`, `block.awk` and `manifest.sh` carry the decisions
inside the tooling. [test/README.md](test/README.md) says how a change is
checked and what the fixture cannot prove.

## Status

In use. One project has been converted with it end to end, and this repository
runs its own workflow.

**devkit is its own first consumer** — of the rules and the skills, not of the
vendoring. It does not bootstrap itself: `AGENTS.md` imports the rule documents
straight from their packs, `.claude/skills` holds generated pointers at
`project/core/skills` rather than copies, and `.devkit/forge.sh` sources the
adapter where it is maintained. Nothing here is a second copy that can fall
behind the original, and `.devkit/gates.sh` fails when a generated pointer, a
manifest entry or the forge contract has gone out of step.

- Bootstrap, manifests and the block mechanism work, and are checked by the
  fixture in [test/](test/README.md).
- The core, shared .NET, `dotnet-core` and GitHub rule documents are written and
  in use.
- The four skills have run against a live project — ticket, branch, bootstrap,
  gates, commit and pull request, through `.devkit/forge.sh` rather than around
  it.

What is not yet proven, and what is being worked on, is on the forge:
[open issues](https://github.com/raisr/devkit/issues).
