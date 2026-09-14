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
| **A shared pack (`shared/dotnet`) is not pickable** | Two stack packs need the same half of the rules. On its own that half installs rules without the gates that enforce them, so a stack pack pulls it in and `--stack` refuses it |
| **The rules reach a session as `@`-imports, never as links** | Claude Code follows an import into context and never a Markdown link. A link looks identical in a diff and silently switches every rule off |
| **Scripts never read JSON** | `jq` is not installed on the maintainer's machine and is not a dependency worth taking. Shell reads `.devkit/config.sh`; the agent reads `devkit.lock.json` |
| **Two workflow modes, `full` and `light`** | The full lifecycle drowns a greenfield repository in tickets. A rule that gets routinely ignored devalues the others |
| **`preflight.sh` was dropped** | Under `light` it added nothing over `gates.sh`, and the workflow mode is evaluated in the skill anyway |

## Where things stand

Done, committed and pushed:

1. **Scaffolding** — `project/bootstrap.sh`, `project/manifest.sh`,
   `project/block.awk`, per-pack `manifest.list`. Verified end to end against
   throwaway repositories, including a real `git clone` from GitHub.
2. **Rule documents** — `AGENTS.core.md`, `AGENTS.dotnet.md`,
   `AGENTS.dotnet-core.md`, `AGENTS.dotnet-legacy.md`, `AGENTS.github.md`,
   `AGENTS.gitlab.md`, extracted from CashPrism with a rule-by-rule coverage
   check that the maintainer approved, then corrected — see the section below.
3. **Skills** — `devkit-sync`, `commit-message`, `create-issue`,
   `implement-feature`, all forge-neutral through `.devkit/forge.sh`.
4. **A fixture** — `test/build-sample-repo.sh`, `test/check-sample-repo.sh`.

## The CashPrism bootstrap and what it uncovered (2026-09-11 → 2026-09-14)

The maintainer ran `bootstrap.sh` against a real repository for the first time
— CashPrism, `D:\Dev\raisr\CashPrism`, branch `feature/40-adopt-devkit`, from
Git Bash on Windows (native PowerShell can't run it — it's a bash script).
Four items came out of it. **All four are done**; what follows is the record of
what was decided and why, so none of it gets re-opened or re-derived.

### A. `--main-branch` defaulted to the current branch — fixed

`bootstrap.sh` took `symbolic-ref HEAD`, so bootstrapping from a feature branch
wrote that branch into `DEVKIT_MAIN_BRANCH`. It now resolves, in order:
`--main-branch` → `refs/remotes/origin/HEAD` → `origin/main` or `origin/master`
→ the current `HEAD`. Everything offline; `git remote show origin` was rejected
because it goes to the network and hangs without access.

It **warns** rather than refuses when it falls back to the current branch and
that is not `main`/`master`. Refusing would break the greenfield case without a
remote, which the README documents.

Measured across five cases: feature branch with `origin/HEAD` → `main`; remote
without `origin/HEAD` but with `origin/main` → `main`; no remote on `main` →
`main`; no remote on `feature/y` → `feature/y` plus the warning; explicit
`--main-branch develop` → `develop`.

### B. Ported rules that were factually wrong — corrected

Worked out with the maintainer through `grill-me`, after diffing CashPrism's
`Agents.md`, its `.editorconfig`, its `Directory.Build.props` and its own three
skills against the three ported files. Five corrections:

| Slug | What was wrong | What holds now |
|---|---|---|
| `core.git` | "Agents change files only" was never a CashPrism rule; it came from the personal profile and contradicted the skills the same package ships | The instruction that starts a change covers the branch, the request, the review replies and deleting the branch. Only the commit message still stops — it is the one text reaching others under a human name without the `core.signature` marking, and published history is never rewritten. Switchable with `DEVKIT_COMMIT_APPROVAL`, bootstrap sets `ask` |
| `core.tests` | Three sentences spoke of "projects", a solution concept, in a document whose own header promises rules that hold in every repository — and they were duplicated in `dotnet.tests`, where the exception to them also lives | Core keeps what is language-neutral. Everything with *project* lives once, in the .NET rules |
| `core.architecture` | "A heavy dependency stays contained in the one project that needs it" had no original. It was the Anonymiser/ClosedXML rule generalised, and that rule was about output fidelity, not dependency containment | Two questions decide placement, and the publisher is neither: does it run in a unit test without touching anything outside the process, and who calls whom. Driven dependencies get an interface and live in infrastructure; driving ones — web framework, CLI, scheduler, consumer — live in presentation or host and get none. Whether infrastructure is one project or several is written into the project's own `AGENTS.md`; unwritten means one |
| `dotnet.style` | Four of five sentences restated `.editorconfig`, two of them settings that stand at `suggestion` and therefore break nothing | Only what the file cannot express stays. What is meant to bind is raised to `warning` in the block — the severity is the knob, not a second sentence |
| `dotnet.gates` | The table claimed "0 warnings, 0 errors" while `gate_build` only checked the exit code; warning-freedom rode entirely on a `Directory.Build.props` the project owns | `-warnaserror` moved onto the gate itself. It also promotes the NuGet audit warnings, so an advisory can turn the build red without a code change — decided deliberately: a known-vulnerable package is a reason not to commit |

### The dotnet pack split

Raised during B, decided during B, done: .NET Framework rules are coming, and
roughly half of the .NET rules are shared with them.

```
project/shared/dotnet/         rules true of .NET whatever the runtime
project/stacks/dotnet-core/    net5+: compiler, style, logging, config, gates
project/stacks/dotnet-legacy/  .NET Framework: MSBuild gates, C# 7.3
```

`shared/` is **not pickable**. A stack pack pulls it in with a `+shared/dotnet`
line at the top of its `manifest.list`; `--stack dotnet` is refused, because on
its own it would install rules without the gates that enforce them. Slugs:
`dotnet.` for the shared pack, `dotnet-core.` and `dotnet-legacy.` for the
packs on top.

Two things worth not re-deriving:

- **The name `dotnet-core` was argued against and kept.** ".NET Core" is a
  retired product name — it ended at 3.1, and net5 and later are officially
  just ".NET", so the pack names a platform its users do not run. The
  maintainer decided for it anyway. Do not change it back to `dotnet-modern`
  without asking.
- `dotnet-legacy` **has never been executed.** Its rules were written from the
  MSBuild, NuGet and VSTest command surface. Its `gates.sh` says so in its own
  header. A failure there is a bug in the pack, not in the project. Build tools
  a specific project layers on top are deliberately not in it: which gates must
  pass is the rule, how they are invoked is the project's.

### C. The shared rule files never loaded — fixed, and it was bigger than it looked

`project/core/templates/AGENTS.md` linked the vendored files as Markdown.
Claude Code follows `@`-imports, never `[text](file)`, so the rule documents sat
on disk and were read by nobody.

Measuring it turned up the larger half: **the bootstrap wrote no `CLAUDE.md` at
all.** In a freshly bootstrapped repository nothing loaded — not even the
project's own `AGENTS.md`. `templates/CLAUDE.md`, one line of `@AGENTS.md`, is
now a core template, and the links are imports.

Verified in real `claude -p` sessions with every tool disabled and a distinct
canary in each rule file. Greenfield: all five files reported back. Missing
`AGENTS.local.md`, the case for anyone who clones: the import is ignored, no
error.

**The case that actually matters came out of the fixture (D):** in a repository
that already owns `AGENTS.md` and `CLAUDE.md`, both are `template` targets, both
are kept — and the chain then has a silent gap. Everything looks installed and
no rule is read. `bootstrap.sh` now ends with a `NEXT STEPS` block naming the
exact import lines that are missing, and the `git mv`-through-a-temporary-name
recipe where the file is spelled `Agents.md`. Windows matches the name whatever
its case, so nothing else would have complained.

The full consumer path — fixture, bootstrap, both renames, imports added — was
walked by hand on 2026-09-14 and the session reported all five canaries.

### D. The throwaway-repo recipe became a fixture

`test/build-sample-repo.sh`, `test/check-sample-repo.sh` and `test/fixtures/`.
See *Testing a change here* below for what they do and what they still cannot
prove.

### What this means for CashPrism

It carries the broken bootstrap output on `feature/40-adopt-devkit`. Two things
to know before resuming:

- `.devkit/config.sh` is a `template`, and a second bootstrap run leaves it
  alone — measured, it reports `kept`. `DEVKIT_MAIN_BRANCH` there needs
  correcting by hand, or the file deleted before re-running.
- The stack flag is now `--stack dotnet-core`, not `--stack dotnet`.

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
          --forge github --stack dotnet-core --workflow full --assignee raisr
   ```

   It ends with a `NEXT STEPS` block, because CashPrism already owns both files
   the import chain runs through. Do what it says; it prints the exact lines.

4. Reduce `Agents.md` to what is genuinely project-specific, add the imports
   `NEXT STEPS` listed, and rename it. Then `Claude.md` → `CLAUDE.md` with the
   content `@AGENTS.md`. **Until this is done not a single rule is in force** —
   the files are on disk and nothing imports them.
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

The legacy side of that project is .NET Framework 4.8 with MSBuild and Cake.
`stacks/dotnet-legacy` now exists for it and has never been executed — the
first bootstrap there is what verifies it. Its `gates.sh` calls MSBuild and
VSTest directly; a repository that drives its build through Cake replaces the
gate bodies with a call into that, which is the project's job and not the
pack's.

## Known gaps

- **`forges/gitlab/forge.sh` has never run.** Treat a failure there as a bug in
  the adapter, not in the calling skill. The file says so in its header.
- **`stacks/dotnet-legacy` has never run either.** Same standing as the GitLab
  adapter: written from a command surface, not from a working build.
- **The forge-facing skills have not been run against a live project.** Only
  `devkit-sync` has been exercised, against a test repository.
- **`machine/` is empty.** First candidate is the Windows setup: tool list, git
  credential configuration, the `D:\Dev` layout.
- **Multi-stack is supported but untried.** `.editorconfig` and `.gitignore`
  are blocks partly so that two stacks can coexist. The shared-pack mechanism
  exercises part of it — `dotnet-core` installs two block sources into each
  file and the fixture asserts they stay separate — but two *independent*
  stacks in one repository is still untested.
- **`DEVKIT_COMMIT_APPROVAL` reaches existing repositories only through
  `/devkit-sync`.** `.devkit/config.sh` is a template, so a repository
  bootstrapped before the key existed will not have it. The skills default to
  `ask` when it is absent, so nothing breaks; the key arrives when sync reports
  that the template moved on.
- **Commit trailers were ruled on (2026-09-11): they stop.** Commits here carry
  no `Co-Authored-By` and no session link, because `forge.commits` — shipped by
  this very repository — forbids them. The global attribution default does not
  apply in this repo.

## Testing a change here

There is no test suite. There is a fixture, and it is the whole of it:

```bash
bash -n project/bootstrap.sh                 # and every other .sh

r="$(bash test/build-sample-repo.sh)"
bash project/bootstrap.sh --repo "$r" --forge github --stack dotnet-core --workflow full
bash test/check-sample-repo.sh "$r"
```

`build-sample-repo.sh` makes a repository with the properties that actually
break things: a real remote with `origin/HEAD`, checked out on a feature
branch, already owning `Agents.md`, `Claude.md`, `.gitignore` and
`.editorconfig`, with a solution file to find. Commit identity and timestamps
are fixed, so two runs produce the same hashes.

`check-sample-repo.sh` asserts, by grep and diff rather than by reading the
output: the resolved default branch, the config keys, balanced and
non-duplicated block markers, the project's own lines surviving *outside* the
blocks, a `@`-import for every managed rule file with no Markdown link among
them, the four skills, and that a second bootstrap run changes no file.

**Where it still falls short, and this has not changed:** the fixture proves
the import lines are on disk and spelled as imports. It cannot prove a session
loads them. That needs Claude Code opened in the bootstrapped repository,
asking for something only `AGENTS.core.md` says. It was done by hand on
2026-09-14 for both the greenfield path and the full consumer path, including
the renames — see the *Findings* section above.

## Conventions in this repository

`AGENTS.md` in the root is binding. The short version: everything is English,
`project/` must contain nothing project-specific, a file that is not in a
`manifest.list` is never installed anywhere, and slugs are identifiers rather
than headings. Agents change files only — commits are the maintainer's call.
