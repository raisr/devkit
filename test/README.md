# test

A sample consumer repository and the assertions a bootstrap run has to satisfy.
Nothing here is ever copied into a project; `bootstrap.sh` and `devkit-sync`
read only `project/`.

There is no test suite beyond this. What there is:

```bash
bash -n project/bootstrap.sh                 # and every other .sh

r="$(bash test/build-sample-repo.sh)"
bash project/bootstrap.sh --repo "$r" --forge github --stack dotnet-core --workflow full
bash test/check-sample-repo.sh "$r"

bash test/check-sync.sh                      # builds its own world, see below
bash test/check-markdown-gates.sh            # so does this one
```

## What the fixture is

`build-sample-repo.sh` makes a repository with the properties that actually
break things, rather than an empty one where the right answer and the wrong one
coincide:

- a real remote, with `origin/HEAD` pointing at the default branch
- checked out on a **feature** branch, not the default one
- already owning `Agents.md`, `Claude.md`, `.gitignore` and `.editorconfig`
- a solution file under `src/`, and a decoy copy under `.vs/` that sorts first
- a skill the devkit once shipped and dropped, next to one the project wrote

Commit identity and timestamps are fixed, so two runs produce the same hashes
and a difference between two fixtures means a real difference.

## What the checks assert

`check-sample-repo.sh` uses grep and diff, never "read the output and judge it":
the resolved default branch, the config keys, the solution path, balanced and
non-duplicated block markers, devkit blocks sitting *above* the project's own
lines with `root = true` still in the preamble, an `@`-import for every managed
rule file with no Markdown link among them, the four skills, that neither the
dropped file nor the project's own skill was deleted, and that a second
bootstrap run changes nothing.

Then, because it leaves the fixture on two stacks: a re-run with an added stack
has to bring `DEVKIT_STACKS` in `.devkit/config.sh` with it, while leaving
`DEVKIT_WORKFLOW` — a project decision — where the project put it.

Last, the case the block mechanism exists for: **two stacks that set the same
key for the same file type**. No shipped pack can produce it — `shared/dotnet`
and `dotnet-core` both write into `[*.cs]` but share no key, and
`dotnet-legacy` has no `.editorconfig` block at all — so the script copies
`project/` to a temporary directory and adds a stack pack that lives only
inside the test.

It then bootstraps the collision **both ways round** and asserts that the winner
flips: with `--stack dotnet-core --stack zz-collide` the synthetic pack wins,
with the flags reversed `dotnet-core` does. One direction alone would pass
without ever testing the claim — which is how the first version of this
assertion was wrong, and how the mutation run caught it.

That chain is the design end to end: `manifest_packs` orders the packs, `block.awk`
appends each new block after the last devkit one, and `.editorconfig` resolves
a conflict by taking the later section. So a stack beats the shared pack it
builds on, and with two stacks **the one named last on the command line wins**.

## What the sync check asserts

`check-sync.sh` covers the other script, `collect.sh`, and builds its own world
to do it: a clone of this repository as a mutable *upstream*, and a sample
repository bootstrapped **from that clone**. Both sides have to start from the
same content or the three hashes never line up.

It then provokes one situation at a time and compares the columns `collect.sh`
prints: an untouched file; a change upstream with the repository clean; a local
edit with upstream clean; both sides changed; a block target whose marker was
deleted; a template that moved on upstream; a template that is gone; and the two
kinds of orphan.

Every special value is asserted against its own baseline first — that an intact
block reports a hash and not `no-marker`, that a present template reports
`owned` and not `missing`. Without that, the interesting assertions would pass
just as happily against a `collect.sh` that printed those words for everything.

The clone is of committed state, so an uncommitted change in the working tree is
invisible to it. That is deliberate: a consumer syncs against what was pushed.

## What the markdown check asserts

`check-markdown-gates.sh` covers the three gates the `markdown` pack ships.
They are the one piece of shipped logic this repository does not run on itself
— it has no stack — so the script bootstraps a throwaway repository with
`--stack markdown` and drives each gate **both red and green**: a broken link,
a document missing from the index, a subdirectory the parent index does not
reach, a second H1, a skipped heading level.

Bootstrapping rather than copying the template into place is the point. A
manifest entry that never arrives would leave every assertion below it testing
a file that is not there.

Three of the assertions are about what the gates must *not* report, and they
carry as much weight as the red ones: an external URL that is dead is none of
the gate's business, a hash inside a fenced code block is not a heading, and a
file with no heading at all is a fragment — `CLAUDE.md` is one line long and
has no H1, so a gate that demanded one would turn every freshly bootstrapped
repository red on the day it was created. That happened, and the first
assertion in the script is the one that caught it.

## What it cannot prove

**Whether the rules reach a session.** The assertions prove the import lines are
on disk and spelled as imports. Whether Claude Code pulls them into context is
only answerable by opening a session in the bootstrapped repository and asking
for something that is written nowhere but `AGENTS.core.md`. Do that by hand
after the script is green — it is the one check that matters most and the one
no script can make.

**Whether `/devkit-sync` judges right.** `collect.sh` decides nothing by
design: it prints `upstream` and `installed`, and the agent reads
`devkit.lock.json` alongside and decides. `check-sync.sh` asserts the input to
that judgement, never the judgement. Two of the cases have no mechanical
signature at all and are walked by hand:

1. **A wording change against a changed rule.** Both produce the identical
   signature — *changed upstream, clean here*. What separates them is the
   content of the diff, which is where `devkit-sync/SKILL.md` says *"read the
   actual diff"*. Provoke it by editing a rule document in a local devkit
   checkout twice: once fixing a typo, once adding a sentence that binds. Run
   `/devkit-sync` in a bootstrapped repository against that checkout. The first
   must be applied silently and shown in the collected diff; the second must be
   put to you as a question.
2. **A new core rule that contradicts a project rule.** Every hash matches, so
   nothing in the report points at it. Add a rule to `AGENTS.core.md` that the
   sample repository's own `AGENTS.md` already decides differently, and run the
   sync: it has to notice by reading the two documents against each other, and
   present the conflict.

Both also cover the deviations machinery: record one, run the sync again and the
question must not come back; then change that rule upstream and it must, saying
why.
