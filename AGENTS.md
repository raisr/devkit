# AGENTS.md — devkit

Rules for working in this repository. It prescribes; `README.md` explains.

This repository is the source of the rules that other repositories vendor, and
it is also their first consumer. What it does **not** do is vendor them to
itself: there are no copies of the rule documents at the root, and
`bootstrap.sh` is never run against this repo. Everything below points at the
pack where the file is maintained.

## Shared rules

These are imports, not links: they pull the file into the session. A Markdown
link is never followed, so turning one into a link switches the rules off with
nothing to see.

@project/core/AGENTS.core.md — rules that hold in every repository
@project/forges/github/AGENTS.github.md — conventions for GitHub, the forge this repository is on

@AGENTS.local.md — personal, machine-specific, git-ignored; wins on conflicts.
The import is ignored where the file does not exist.

A skill that names a file at the repository root means the one in its pack:
`AGENTS.core.md` is `project/core/AGENTS.core.md`, and `AGENTS.<forge>.md` is
`project/forges/github/AGENTS.github.md`. There are no stack packs here —
`DEVKIT_STACKS` in `.devkit/config.sh` is empty on purpose, because a stack pack
generalised from this single repository would be a guess. The rules that are
specific to it are in *Boundaries* below, and they move into a pack when a
second repository needs them.

`.claude/skills` holds generated pointers at `project/core/skills`, not copies —
see `.devkit/stubs.sh`. `maintain` is the exception: it is local to this
repository and deliberately not under `project/`.

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
means it is never installed anywhere. The manifest is what makes a file real,
and `.devkit/gates.sh` fails when one is missing.

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

  The one carve-out: `DEVKIT_FORGE` and `DEVKIT_STACKS` in `.devkit/config.sh`
  name the packs that are installed, which is the bootstrap's own argument and
  not a decision. `bootstrap.sh` rewrites those two lines on a re-run and
  nothing else in the file. Adding a third such key needs the same test as the
  first two: would a stale value make the tooling quietly do the wrong thing?
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
same commit — `.devkit/gates.sh` fails when only one of them did.

## Tests

`core.tests` binds here too, and the fixture under `test/` is what it means: a
change to `bootstrap.sh`, `block.awk` or `manifest.sh` without a new assertion
in `test/check-sample-repo.sh` counts as unfinished. The fixture is the only
test this repository has.

## Boundaries

- No secrets, no tokens, no personal paths — this repository is public.
- No new tool dependency in a script without justification. `git`, `sed`,
  `awk` and `find` are available everywhere; `jq` is not, so shell scripts
  must not need it. JSON is read by agents, not by scripts.
- Shell scripts stay POSIX-friendly bash and must pass `bash -n`.

## Deviations from the shared rules

Rules from `AGENTS.core.md` or a forge pack that deliberately do not apply here.

| Rule | Deviation | Why |
|---|---|---|
| `core.deviations` | recorded in this table only, with no `devkit.lock.json` | The lock file answers one question: which devkit commit was a decision made against. This repository *is* the devkit, so the answer is always its own history, which git already keeps. A lock file here would carry an empty file list and a version nobody maintains. |
| `forge.changelog` | `CHANGELOG.md` is keyed by date, not by version, and claims no Semantic Versioning | devkit has no releases and no tags — `main` is the truth and a consumer's lock file records a commit and a date. An `[Unreleased]` section that is never released would be a heading that lies. |
