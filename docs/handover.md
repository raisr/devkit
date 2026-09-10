# Handover

Written 2026-09-10, at the end of the session that created this repository.
It exists so the next session does not have to re-derive the model or re-open
decisions that were already argued through.

`README.md` says what the devkit *is* and how to use it. This document says
**why it is shaped this way** and **what is left to do**.

## The problem it solves

The same developer starts new projects indefinitely. Every one of them wants
the same rules, the same skills and the same scaffolding — but with different
flavours: .NET or something else, GitHub or GitLab, greenfield or a team
repository. Before this, those rules lived in one project (CashPrism) and half
of them were duplicated in a personal profile that nobody else can see.

## The model, and why

| Decision | Why it was taken |
|---|---|
| **Repositories are self-contained.** Bootstrapping copies real files in; nothing is referenced from outside | A colleague who clones a project must get the full rules without installing anything. This is the constraint everything else follows from |
| **Nothing important lives in a personal profile** | A rule only the maintainer can see is not a rule for the team. The personal profile keeps communication style only |
| **Vendoring with an update path**, not a template to copy once | Copies drift. The update path is what makes this different from a starter template |
| **`project/` and `machine/` are separate top-level areas** | The tooling reads only `project/`, so machine setup can grow to any size without a chance of leaking into a project repository |
| **`main` only, no tags or releases** | One-person kit. Tagging is ceremony that gets forgotten; the lock file records a commit and a date |
| **Modes: managed / block / template / dir** | Whole-file replacement is deterministic and needs no merge. `block` exists only for files both sides write into (`.gitignore`, `.editorconfig`). `template` is for anything carrying a project decision |
| **Sync is a conversation, not a `cp`** | A hash finds an edited file. It cannot find a new core rule that contradicts a project rule. That comparison needs judgement, so the skill reads both and asks |
| **Deviations are recorded twice** | Readable in the project `AGENTS.md` for humans, machine-readable in `devkit.lock.json` so the same question is not asked twice |
| **Stable section slugs (`{#core.async}`)** | A deviation must point at a rule and survive rewording of the text beneath it. Renaming a slug is a breaking change |
| **Both forge packs use `forge.*` slugs** | A repository that moves from GitHub to GitLab keeps its recorded deviations |
| **Scripts never read JSON** | `jq` is not installed on the maintainer's machine and is not a dependency worth taking. Shell reads `.devkit/config.sh`; the agent reads `devkit.lock.json` |
| **Two workflow modes, `full` and `light`** | The full lifecycle drowns a greenfield repository in tickets. A rule that gets routinely ignored devalues the others |
| **`preflight.sh` was dropped** | Under `light` it added nothing over `gates.sh`, and the workflow mode is evaluated in the skill anyway |

## Where things stand

Done, committed and pushed:

1. **Scaffolding** — `project/bootstrap.sh`, `project/manifest.sh`,
   `project/block.awk`, per-pack `manifest.list`. Verified end to end against
   throwaway repositories, including a real `git clone` from GitHub.
2. **Rule documents** — `AGENTS.core.md`, `AGENTS.dotnet.md`,
   `AGENTS.github.md`, `AGENTS.gitlab.md`, extracted from CashPrism with a
   rule-by-rule coverage check that the maintainer approved.
3. **Skills** — `devkit-sync`, `commit-message`, `create-issue`,
   `implement-feature`, all forge-neutral through `.devkit/forge.sh`.

## What is left

All three items below are **not work in this repository**. They happen in the
consuming project, in a session opened there, and they are what turns this from
a plausible design into a tested one. Only the fixes they uncover come back
here.

### 4. Convert CashPrism, using the real workflow

CashPrism (`D:\Dev\raisr\CashPrism`, GitHub, .NET, workflow `full`) is where
these rules came from, so converting it is what proves the split lost nothing.

Do it as an ordinary change under the `full` lifecycle rather than as a
mechanical bootstrap. That is the only way to exercise the three forge-facing
skills against a live project — they have never run outside a test repository.

There is one unavoidable chicken-and-egg: the change that installs the skills
cannot use them. So:

1. In a CashPrism session, file the ticket with the **existing** `create-issue`
   skill that repository still has.
2. Branch `feature/<n>-adopt-devkit`.
3. Run the bootstrap. It clones this repository itself, so the session needs no
   access to a local devkit checkout:

   ```bash
   d="$(mktemp -d)" \
     && git clone --depth 1 https://github.com/raisr/devkit "$d/devkit" \
     && bash "$d/devkit/project/bootstrap.sh" \
          --forge github --stack dotnet --workflow full --assignee raisr
   ```

4. Reduce `Agents.md` to what is genuinely project-specific and rename it, then
   `Claude.md` → `CLAUDE.md` with the content `@AGENTS.md`.
5. **Restart the session.** Claude Code reads `.claude/skills/` at start, so the
   four freshly vendored skills only become invocable after a restart. Before
   that they are files on disk and nothing more.
6. Carry on with the new skills: gates, `commit-message`, the pull request, the
   review round, the merge.

Details that bite:

- **Windows is case-insensitive.** Rename `Agents.md` through a temporary name
  with `git mv`, or Git will not record a rename at all.
- What stays in the project `AGENTS.md`: the FinanzGuru overview and identity
  rule, the database-on-local-disk decision, the concrete projects (`Shell`,
  `Web`, `Anonymiser`, `Architecture.Tests`), hosting, domain terms, and an
  empty *Deviations* table. Everything else now lives in the shared files.
- `.editorconfig` and `.gitignore` are replaced by marker blocks whose content
  is the same text those files hold today. Diff them and prove it rather than
  assuming it.
- The bootstrap **overwrites** CashPrism's own three skills. Read them first:
  anything in them the devkit version lacks belongs upstream here *before* the
  conversion, not after.
- Do not slice this into several requests. Between two partial ones the
  repository would carry both the old and the new rules at once, which is worse
  than one large reviewable change.

Success criterion: every rule that `Agents.md` held on 2026-09-09 is still in
force afterwards, either in a shared file or in the project one — and the whole
lifecycle ran through the devkit skills at least once.

### 5. Exercise `/devkit-sync` against a real conflict

Once CashPrism is converted, change a rule here and sync it across. Worth
provoking deliberately:

- a wording-only change, which must be applied without a question
- a rule change, which must be presented
- a locally edited managed file
- a new core rule that contradicts something in the project `AGENTS.md` — the
  case no hash can find
- a destroyed block marker, which must stop the sync rather than be repaired

Then check that a recorded deviation actually silences the repeat question, and
that changing that rule upstream brings it back.

### 6. vNext, when its stack is decided

`D:\Dev\raisr\Getmyglasses\vnext\getmyglasses`, GitLab, greenfield. It is the
first `--forge gitlab` consumer, which means it is also what verifies
`forges/gitlab/forge.sh` — written from the `glab` command surface and never
executed. Expect to fix it function by function.

The legacy side of that project is .NET Framework 4.8 with MSBuild and Cake,
which is what the planned `stacks/dotnet-legacy` pack is for. It does not
exist yet and should not be written before there is a repository that needs it.

## Known gaps

- **`forges/gitlab/forge.sh` has never run.** Treat a failure there as a bug in
  the adapter, not in the calling skill. The file says so in its header.
- **The forge-facing skills have not been run against a live project.** Only
  `devkit-sync` has been exercised, against a test repository.
- **`stacks/dotnet-legacy` does not exist.**
- **`machine/` is empty.** First candidate is the Windows setup: tool list, git
  credential configuration, the `D:\Dev` layout.
- **Multi-stack is supported but untried.** `.editorconfig` and `.gitignore`
  are blocks partly so that two stacks can coexist; nothing has tested it.
- **The commits in this repository carry a `Co-Authored-By` trailer and a
  session link**, which the forge rules this very repository ships forbid
  inside a repository. The maintainer was told and has not ruled on it. Either
  the rule gets an exception for this repo, or the trailers stop.

## Testing a change here

There is no test suite. What there is:

```bash
bash -n project/bootstrap.sh                 # and every other .sh
```

Then a throwaway repository:

```bash
t="$(mktemp -d)" && git -C "$t" init -q -b main && mkdir -p "$t/src"
bash project/bootstrap.sh --repo "$t" --forge github --stack dotnet --dry-run
bash project/bootstrap.sh --repo "$t" --forge github --stack dotnet
bash project/bootstrap.sh --repo "$t" --forge github --stack dotnet   # idempotent
```

Worth re-checking after any change to the modes: that a second run keeps
templates, does not duplicate markers, and leaves lines the project added to
`.gitignore` alone.

## Conventions in this repository

`AGENTS.md` in the root is binding. The short version: everything is English,
`project/` must contain nothing project-specific, a file that is not in a
`manifest.list` is never installed anywhere, and slugs are identifiers rather
than headings. Agents change files only — commits are the maintainer's call.
