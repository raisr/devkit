# devkit

Shared development rules, agent skills and project scaffolding, kept in one
place and copied into the repositories that use them.

Nothing here is a runtime dependency. A repository that has been bootstrapped
carries **real files**: the rule documents, the skills, the config. Clone that
repository without this one and everything is still there, readable by anyone,
with or without an agent.

## Two areas

| Area | What it is | Who reads it |
|---|---|---|
| `project/` | Everything that gets copied **into a repository**: rules, skills, editor and ignore settings, templates | `bootstrap.sh` and the `devkit-sync` skill |
| `machine/` | Everything that sets up a **development machine**: tools, git configuration, folder layout | you, by hand |

The sync tooling only ever looks below `project/`. `machine/` can grow to any
size without a chance of it leaking into a project repository.

## Packs

`project/` is cut along the two axes that actually differ between projects:

```
project/
  core/            rules that hold everywhere, the skills, the templates
  stacks/dotnet/   .NET rules, .editorconfig and .gitignore blocks, gates
  forges/github/   branch, commit, issue and pull request conventions + gh adapter
  forges/gitlab/   the same, for GitLab + glab adapter
```

A repository picks one forge and any number of stacks. Each pack declares what
it installs in its own `manifest.list`; `project/manifest.sh` reads them.

## Bootstrapping a repository

Run this **inside the repository you want to set up**. It needs `git` and
nothing else — no agent, no account, no `jq`:

```bash
d="$(mktemp -d)" \
  && git clone --depth 1 https://github.com/raisr/devkit "$d/devkit" \
  && bash "$d/devkit/project/bootstrap.sh" --forge github --stack dotnet
```

Under Git Bash on Windows, use `mktemp -d` as shown — `$TEMP` holds a path with
backslashes that `bash` does not resolve.

| Flag | |
|---|---|
| `--forge github\|gitlab` | required |
| `--stack <name>` | repeat it for a repository with more than one stack |
| `--workflow full\|light` | default `light`; see *Workflow* below |
| `--assignee <name>` | who gets assigned to a pull or merge request; defaults to `git config user.name` |
| `--main-branch <name>` | defaults to the current branch |
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
| `AGENTS.md` | template | **the project owns it**; links the managed rules, records deviations |
| `AGENTS.local.md` | template | personal, git-ignored; seeded from `~/.claude/AGENTS.local.md` if you keep one |
| `.devkit/config.sh`, `.devkit/gates.sh` | template | project owns them: forge, workflow, build commands |
| `CHANGELOG.md`, `ROADMAP.md`, `docs/README.md` | template | written once if missing |
| `devkit.lock.json` | — | where the files came from, at which commit, plus the deviations |

*managed* is replaced on sync, *block* is replaced between its markers, and
*template* is written once and never touched again.

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

## Status

Early. The scaffolding and the bootstrap work; the rule documents and the
skills are placeholders being filled in.
