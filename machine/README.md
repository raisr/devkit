# machine

Setting up a development machine: tools to install, git configuration, shell
profile, folder layout.

Nothing here is ever copied into a project repository. `bootstrap.sh` and the
`devkit-sync` skill read only `project/` — this directory is invisible to them
by design, so it can grow without any risk of leaking into a project.

## Status

Empty. The first thing to land here is the Windows setup: the tool list, the
git credential configuration, and the `D:\Dev` layout.
