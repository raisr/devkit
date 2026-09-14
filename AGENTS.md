# AGENTS.md — devkit

Rules for working in this repository. It prescribes; `README.md` explains.

This repository is the source of the rules that other repositories vendor. It
does **not** vendor them itself — there is no `AGENTS.core.md` here, and
`bootstrap.sh` is never run against this repo.

## The two areas are not interchangeable

- `project/` is copied into other repositories. Everything in it must be
  generic: no project name, no path that only exists on one machine, no
  personal preference. If it only makes sense for one repository, it does not
  belong here.
- `machine/` is executed on a development machine and never copied anywhere.
  The sync tooling does not look at it.
- `test/` builds and checks a sample consumer repository. It is not copied
  anywhere either, and nothing in `project/` may depend on it.

Adding a file to `project/` without adding it to the pack's `manifest.list`
means it is never installed anywhere. The manifest is what makes a file real.

## Packs and shared packs

`project/core/`, `project/stacks/*` and `project/forges/*` are pickable: a
repository chooses one forge and any number of stacks.

`project/shared/*` is not. A shared pack holds what two stack packs have in
common, and a stack pack pulls it in with a `+shared/<name>` line at the top of
its own `manifest.list`. It is kept out of `--stack` on purpose: on its own it
would install rules without the gates and templates that make them
enforceable — a repository that looks configured and is not.

A shared pack keeps its own slug prefix (`dotnet.`), and each stack pack on top
of it uses its own (`dotnet-core.`, `dotnet-legacy.`). A rule that moves
between the two is a slug change, and therefore a breaking change.

## Modes

Every manifest entry declares one:

- `managed` — the receiving repository must not edit it. Changes happen here.
- `block:<id>` — the file content is injected into a target between
  `# >>> <id> >>>` and `# <<< <id> <<<`. Only for formats where `#` starts a
  comment, and only for content that is a list, never prose.
- `template` — written once when the target does not exist, then owned by the
  receiving project forever. Anything carrying a version, a path or a project
  decision is a template, not managed.
- `dir` — a whole directory, every file tracked as managed.

Choosing `managed` for something a project legitimately needs to adapt is the
mistake that makes the sync annoying. When in doubt, template.

## Rule documents

- One section per rule group, each with a stable slug: `## Async {#core.async}`.
  A project records a deviation against that slug, so the slug must survive
  rewording of the text beneath it. Renaming a slug breaks every recorded
  decision that points at it — treat it as a breaking change.
- Slug prefixes: `core.` for `AGENTS.core.md`, the pack name for a stack or
  shared pack (`dotnet.`, `dotnet-core.`), and `forge.` for **both** forge
  packs — a repository that moves from GitHub to GitLab keeps its deviations
  pointing at the same rules.
- Prescriptive voice. A rule says what must happen, not what is nice.
- No project may be named in a rule document.

## Forge adapters

`forges/*/forge.sh` is a contract: both packs define the same function names,
and the skills call only those. A skill that mentions `gh` or `glab` directly
is a bug. When the contract grows a function, both adapters grow it in the
same commit.

## Language

Everything in this repository is English: files, comments, commit messages,
issue and pull request text.

## Git

Change files only. No commit, no push, no branch, no pull request unless the
maintainer asks for it.

Conventional commits: `feat:`, `fix:`, `refactor:`, `docs:`, `chore:`.

## Boundaries

- No secrets, no tokens, no personal paths — this repository is public.
- No new tool dependency in a script without justification. `git`, `sed`,
  `awk` and `find` are available everywhere; `jq` is not, so shell scripts
  must not need it. JSON is read by agents, not by scripts.
- Shell scripts stay POSIX-friendly bash and must pass `bash -n`.

## Personal notes

`AGENTS.local.md` next to this file is read as well if it exists, and wins on
conflicts. It is git-ignored and personal.
