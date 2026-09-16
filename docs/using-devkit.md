# Using the devkit in a project

How a repository adopts the shared rules, what lands in it, and how it stays
current. The rules themselves are not explained here — each `AGENTS.*.md` file
states its own.

Everything the devkit installs is a real file in the consumer repository. There
is no runtime dependency: clone that repository without this one and the rules,
the skills and the gates are all still there.

**One worked example runs through this guide**: a GitHub repository on the
`dotnet-core` stack. It is an example, not a recommendation and not a statement
about what is supported. On GitLab, pass `--forge gitlab` and read
`AGENTS.gitlab.md` wherever the text says `AGENTS.github.md`; with another
stack, substitute its name the same way. Nothing else differs — that is what
the forge adapter and the pack layout are for.

## What lands in a repository

```
AGENTS.core.md          rules that hold everywhere          managed
AGENTS.dotnet.md        shared .NET rules                   managed
AGENTS.dotnet-core.md   stack rules, one per stack          managed
AGENTS.<forge>.md       forge conventions, github or gitlab managed
.claude/skills/**       the four skills                     managed
.devkit/forge.sh        gh or glab behind one contract      managed
.gitattributes          line endings                        managed
.editorconfig           between devkit markers              block
.gitignore              between devkit markers              block
CLAUDE.md               one line: @AGENTS.md                template
AGENTS.md               the project's own rules             template
AGENTS.local.md         personal, git-ignored               template
.devkit/config.sh       forge, stacks, workflow, assignee   template
.devkit/gates.sh        the build/test/format commands      template
src/Directory.Build.props                                   template
CHANGELOG.md, ROADMAP.md, docs/README.md                    template
devkit.lock.json        where each file came from           —
```

| Mode | Meaning for you |
|---|---|
| `managed` | do not edit it here; change it in the devkit, it is replaced on sync |
| `block` | the devkit owns the lines between `# >>> devkit:… >>>` and `# <<< devkit:… <<<`; everything else in the file is yours |
| `template` | written once if absent, then yours forever — sync never touches it. The one exception is `DEVKIT_FORGE` and `DEVKIT_STACKS` in `.devkit/config.sh`, which bootstrap keeps in step with its flags |

### The import chain

```
CLAUDE.md → @AGENTS.md → @AGENTS.core.md
                       → @AGENTS.<stack>.md   one line per stack installed
                       → @AGENTS.<forge>.md   the one forge, github or gitlab
                       → @AGENTS.local.md     (git-ignored, ignored when absent)
```

These are `@`-imports, not Markdown links. A link is never followed into a
session, so turning an import into a link switches those rules off with nothing
visible to see. If a rule seems not to apply, check this chain first.

## Bootstrap

Needs `git` and `bash`, nothing else. No agent, no account, no `jq`. It writes
files and never stages or commits.

### A new repository

Run it **inside the repository** you want to set up:

```bash
d="$(mktemp -d)" \
  && git clone --depth 1 https://github.com/raisr/devkit "$d/devkit" \
  && bash "$d/devkit/project/bootstrap.sh" --forge github --stack dotnet-core
```

Under Git Bash on Windows use `mktemp -d` exactly as shown — `$TEMP` holds a
path with backslashes that `bash` does not resolve.

```
devkit de6cfe0 (2026-09-14)
  repository : /d/Dev/acme/Widgets
  forge      : github
  stacks     : dotnet-core
  workflow   : light

core
  managed   AGENTS.core.md
  managed   .gitattributes
  block     .editorconfig  [devkit:core]
  block     .gitignore  [devkit:core]
  managed   .claude/skills/commit-message/SKILL.md
  …
  template  CLAUDE.md
  template  AGENTS.md
  template  .devkit/config.sh

shared/dotnet
  managed   AGENTS.dotnet.md
  block     .editorconfig  [devkit:shared/dotnet]
  block     .gitignore  [devkit:shared/dotnet]

stacks/dotnet-core
  managed   AGENTS.dotnet-core.md
  block     .editorconfig  [devkit:stack/dotnet-core]
  template  .devkit/gates.sh
  template  src/Directory.Build.props

forges/github
  managed   AGENTS.github.md
  managed   .devkit/forge.sh

  written   devkit.lock.json

Done. Nothing was staged or committed - review with: git -C /d/Dev/acme/Widgets status
Note: no .sln/.slnx found - set SLN in .devkit/gates.sh yourself.
```

The last line is the usual one in an empty repository: there is no solution to
find yet. Fill `SLN` in `.devkit/gates.sh` once the solution exists.

Then review and commit yourself:

```bash
git status
git add -A && git commit -m "chore: adopt the devkit"
```

### An existing repository

Same command. The interesting part is what bootstrap refuses to do — anything
the project already owns is kept, and the script tells you what that leaves
undone. A repository that already had `Agents.md` and `Claude.md`:

```
  kept      CLAUDE.md
  kept      AGENTS.md

LEFTOVERS - the devkit no longer ships these, and nothing references them:

      .claude/skills/implement-feature/preflight.sh

  They were not touched. Delete them, or keep them as your own.

NEXT STEPS - bootstrap kept files the project already owned:

  Agents.md is yours, so these imports were not added. Put them in it:

      @AGENTS.core.md — rules that hold in every repository
      @AGENTS.dotnet.md — rules for dotnet
      @AGENTS.dotnet-core.md — rules for dotnet-core
      @AGENTS.github.md — conventions for github

  Rename it to AGENTS.md as well. Windows matches the name whatever its
  case, so nothing here complains - but the repository is read on other
  machines too. Go through a temporary name so git records the rename:
      git mv Agents.md tmp.md && git mv tmp.md AGENTS.md

  Claude.md is yours. It is the one file a session reads by itself,
  so it has to import the rules file and nothing else:  @AGENTS.md
      git mv Claude.md tmp.md && git mv tmp.md CLAUDE.md

  Until that is done the rule files sit on disk and no session reads them.
```

Take that last sentence literally. Until the import chain is closed, the
bootstrap looks complete and no rule reaches a session. Do the two renames and
paste the four imports into `AGENTS.md` before anything else.

Existing `.editorconfig` and `.gitignore` are not overwritten either: the devkit
blocks are inserted **above** the project's own lines, because both formats let
a later line win. `root = true` stays in the preamble where it means something.

### Adding a stack later

Re-run bootstrap with every stack the repository uses, not just the new one:

```bash
bash "$d/devkit/project/bootstrap.sh" --forge github \
  --stack dotnet-core --stack dotnet-legacy
```

Re-running is safe and idempotent: managed files are rewritten, blocks are
replaced between their markers, templates are left alone. The run reports what
it changed in the config:

```
  updated   .devkit/config.sh  [DEVKIT_STACKS]
```

`DEVKIT_FORGE` and `DEVKIT_STACKS` are the two lines in `.devkit/config.sh` that
bootstrap keeps in step with its own flags, even though the file is a template.
They name the packs that are installed rather than anything the project decided,
and `/devkit-sync` reads exactly them to work out which files to compare — left
stale, the added stack would stay invisible to every later sync. Everything else
in that file is yours and survives the re-run, including `DEVKIT_WORKFLOW`.

What a re-run does **not** do is remove a stack you dropped from the flags: its
rule file and its `.editorconfig` block stay on disk. Delete those yourself.

### The flags

| Flag | |
|---|---|
| `--forge github\|gitlab` | required |
| `--stack <name>` | `dotnet-core`, `dotnet-legacy`; repeat for more than one |
| `--workflow full\|light` | default `light`; see *Daily work* |
| `--assignee <name>` | assignee for pull or merge requests; defaults to `git config user.name` |
| `--main-branch <name>` | defaults to what `origin/HEAD` points at; only a repository without a remote falls back to the current branch |
| `--repo <path>` | bootstrap a different repository than the current one |
| `--dry-run` | print what would happen, write nothing |

`--stack dotnet` is refused on purpose. `shared/dotnet` holds what both .NET
stacks have in common and arrives with either of them; on its own it would
install rules without the gates that enforce them.

`--main-branch` matters when adopting on a feature branch, which is the normal
case. Bootstrap resolves the default branch offline from `origin/HEAD`, never
from the checked-out branch — pass the flag only when there is no remote and the
current branch is not the default one.

### Dry run

```bash
bash "$d/devkit/project/bootstrap.sh" --forge github --stack dotnet-core --dry-run
```

Prints the same file list, writes nothing, and answers the question worth asking
first: which of your files would be `kept` rather than written.

## The first ten minutes after a bootstrap

1. **`.devkit/config.sh`** — check `DEVKIT_MAIN_BRANCH` and `DEVKIT_ASSIGNEE`,
   and decide `DEVKIT_WORKFLOW`. `DEVKIT_FORGE` and `DEVKIT_STACKS` are
   bootstrap's to maintain — change a pack by re-running bootstrap, not by
   editing them here.
   `DEVKIT_COMMIT_APPROVAL` starts on `ask`; leave it there until the commit
   messages this repository produces have earned `auto`. Personal overrides go
   in `.devkit/local.sh`, which is git-ignored and sourced afterwards.
2. **`.devkit/gates.sh`** — confirm `SLN`, and adjust the three `gate_*`
   functions to what this repository actually builds. It is a template: it is
   yours, and sync will never argue with your version.
3. **`AGENTS.md`** — fill *Overview*, *Tech stack*, *Architecture* and
   *Domain terms*. Keep it prescriptive; explanation belongs in `docs/`.
4. **Run the gates once**, before writing any code:

   ```bash
   bash .devkit/gates.sh
   ```

   ```
   === build ===
     PASS
   === test ===
     PASS
   === format ===
     FAIL - expected: no formatting changes needed
       …last 15 lines of the log…

   GATES: not ready
   ```

   A red gate on day one is a finding about the repository, not about the
   devkit. Fix it now — every later commit runs through here.
5. **Check that the rules actually arrive.** Open a session in the repository
   and ask for something written nowhere but `AGENTS.core.md`. This is the one
   check no script can make, and the one that catches a broken import chain.

## Daily work

Four skills are installed, and they call each other:

| Skill | Does |
|---|---|
| `/implement-feature` | the whole lifecycle: ticket, branch, implementation, gates, commit, request, review loop |
| `/create-issue` | drafts a ticket in the required schema, files it after a yes |
| `/commit-message` | drafts the commit message, commits and pushes after a yes |
| `/devkit-sync` | updates the vendored devkit files |

`DEVKIT_WORKFLOW` decides how much of the lifecycle applies:

- **`full`** — ticket, `feature/<n>-<slug>` branch, changelog entry, gates,
  commit, pull or merge request, review round. Done when the request is merged.
- **`light`** — branch, gates, commit. No ticket, no request, no review round.
  The rules, the tests and the gates bind exactly as they do under `full`.

Switching modes is a decision about the repository, taken deliberately — not a
way past a step that is failing.

Skills never call `gh` or `glab`. Everything goes through `.devkit/forge.sh`,
which is why the same skill works on GitHub and GitLab:

```bash
. .devkit/config.sh && . .devkit/forge.sh
forge_check                     # authenticated? which project?
forge_issue_list_open
forge_pr_view 42
```

## Staying up to date — `/devkit-sync`

Run `/devkit-sync` in the consumer repository. It clones the devkit, compares
what it finds against the vendored files **and** against the project rules in
`AGENTS.md`, settles every judgement call with you, and writes files. It never
stages and never commits.

The data it works from comes from one script, which decides nothing itself:

```bash
bash .claude/skills/devkit-sync/collect.sh
```

```
SOURCE: https://github.com/raisr/devkit
CLONE: /tmp/tmp.97oDGqkhIq/devkit
UPSTREAM_COMMIT: de6cfe0
UPSTREAM_DATE: 2026-09-14
FORGE: github
STACKS: dotnet-core
WORKFLOW: light

=== packs available upstream ===
stacks: dotnet-core dotnet-legacy
forges: github gitlab
shared: dotnet

=== files ===
# source|target|mode|marker|upstream|installed
core/AGENTS.core.md|AGENTS.core.md|managed||76ce245b…|76ce245b…
core/editorconfig.block|.editorconfig|block|devkit:core|2c002993…|2c002993…
core/templates/config.sh|.devkit/config.sh|template||8d2946a8…|owned
stacks/dotnet-core/templates/gates.sh|.devkit/gates.sh|template||4208fbaa…|owned
forges/github/forge.sh|.devkit/forge.sh|managed||2df800d5…|2df800d5…

=== repository state ===
branch: main
working tree: 0 changed file(s)
```

It needs the network and fails loudly rather than working from a stale clone.
Pass a path to sync against a local checkout — useful while developing the
devkit itself:

```bash
bash .claude/skills/devkit-sync/collect.sh /path/to/devkit
```

### How a file is judged

Three hashes, all of them hashes of **devkit source content**, which is what
makes them comparable: `recorded` from `devkit.lock.json` (what was installed
last time), `upstream`, and `installed`.

| recorded vs upstream | recorded vs installed | Meaning |
|---|---|---|
| same | same | nothing happened |
| same | differs | edited locally — you are asked |
| differs | same | changed upstream, clean here — wording is applied silently, a changed rule is put to you |
| differs | differs | changed on both sides — you are asked |

A `template` is judged on one axis only. Its `installed` column reads `owned`,
not a hash: the file was written once through token substitution and has been
yours since. Sync can only tell you that the upstream template moved on — for
example that `.devkit/config.sh` gained a key your copy does not have. Taking
anything across is your call, by hand.

`no-marker` means a block target lost its markers. Sync stops there and asks
rather than appending a second block.

### What no hash can find

Sync also reads the new upstream rules against your `AGENTS.md`, its
*Deviations* table and `AGENTS.local.md`. A new core rule that contradicts
something this project decided is a conflict even when every hash matches, and
it is presented like any other.

### Deviations

When you decide a rule does not apply here, the decision is recorded twice:

- a row in the *Deviations* table of `AGENTS.md` — readable
- an entry in `devkit.lock.json` with the rule slug, the reason and `decidedAt`
  set to the devkit commit it was decided against — machine-readable

The same question is then not asked again **until that rule changes upstream**,
at which point the old decision was made against a text that no longer exists
and sync asks once more, saying so.

Rule slugs (`core.tests`, `dotnet-core.style`, `forge.commits`) are the identity
of a rule. Both forge packs use the `forge.` prefix on purpose, so a repository
moving from GitHub to GitLab keeps its deviations pointing at the same rules.

## Troubleshooting

**The rules are on disk but nothing follows them.** The import chain is broken.
`CLAUDE.md` must contain `@AGENTS.md` and nothing else, and `AGENTS.md` must
`@`-import every managed rule file. Check the spelling of the filenames too:
Windows matches any case, other machines do not.

**A block marker was deleted.** Both bootstrap and sync stop and say which file
and which marker. Repair the pair by hand — rewriting it automatically would
drop whatever ended up between them.

**A file the devkit no longer ships.** Reported as a leftover or, under sync, as
an `orphan`. It is never deleted for you: it might be a skill this project wrote
itself. Decide and remove it yourself.

**`.devkit/config.sh` is missing a key added upstream.** Expected. It is a
template and was written at bootstrap time. The skills default safely when a key
is absent; sync reports that the template moved on. `DEVKIT_FORGE` and
`DEVKIT_STACKS` are the exception — bootstrap adds them if an older config never
had them.

**`/devkit-sync` ignores a stack you added.** Check `DEVKIT_STACKS` in
`.devkit/config.sh`: sync compares only the packs named there. Re-run bootstrap
with every stack the repository uses and it is corrected.

**`LF will be replaced by CRLF` while staging.** Harmless. `.gitattributes`
normalises text files to LF in the repository.

**A cold `gates.sh` run takes tens of seconds.** It runs the real build and the
real tests. That is the point, and it is not a hang.
