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

Last, and only because it leaves the fixture on two stacks: a re-run with an
added stack has to bring `DEVKIT_STACKS` in `.devkit/config.sh` with it, while
leaving `DEVKIT_WORKFLOW` — a project decision — where the project put it.

## What it cannot prove

**Whether the rules reach a session.** The assertions prove the import lines are
on disk and spelled as imports. Whether Claude Code pulls them into context is
only answerable by opening a session in the bootstrapped repository and asking
for something that is written nowhere but `AGENTS.core.md`. Do that by hand
after the script is green — it is the one check that matters most and the one
no script can make.
