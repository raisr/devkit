# Changelog

What changed in the shared rules, packs and tooling, for the people who vendor
them. Read this when `/devkit-sync` asks you a question and you want to know
what is behind it.

The format follows the categories of
[Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/) — `Added`,
`Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`.

Sections are dated, not versioned: devkit has no releases and no tags. `main` is
the truth, and a consumer's `devkit.lock.json` records the commit and the date
it vendored. That makes a date the coordinate that both sides actually share.
This is a deliberate deviation from `forge.changelog`, recorded in
[`AGENTS.md`](AGENTS.md).

The log starts on the day devkit adopted its own workflow. Everything before
that is in the git history.

## 2026-09-16

### Added

- `forge_issue_reply` in both forge adapters. `forge.issues` has always sent a
  finding made while working a ticket into a comment rather than into the
  description, but the contract could only read issues and create them — so the
  one place the rule points at was unreachable through it. The same gap
  `forge_pr_reply` closed for requests, one level up.
- A **Documentation** line in the request body, required by `forge.requests` in
  both forge packs: which document was updated, or `n. a.` with the reason none
  needed it. `core.docs` already made documentation part of the change, but
  nothing ever asked for evidence that it happened, so failing it was invisible
  at review time. The changelog line has worked this way from the start; this is
  the same mechanism for the other half.
- The **Definition of Done** is now copied into the request body as checkboxes
  and ticked box by box, rather than only its deviations being mentioned. A
  fulfilled contract should read as one.
- `forge_pr_reply` and `forge_pr_edit` in both forge adapters. `forge.review`
  has always required a review round to end with a reply on the request, but
  the contract had no function that writes one, and none that corrects a
  request body — so the prescribed loop could only be walked by calling `gh` or
  `glab` directly, which the rules call a bug. Both take a body file, for the
  same reason `forge_issue_create` does.

### Changed

- `test` is now a ticket type and a label, not only a commit type. `forge.commits`
  had always allowed six conventional-commit types while `forge.issues` and
  `forge.labels` named five, so a test-only change could be committed but not
  ticketed. Both forge packs now list the same six words. A repository that
  already ran this workflow needs the `test` label created once — the
  `create-issue` skill reports it as missing until then.

## 2026-09-14

### Added

- `docs/using-devkit.md` — the guide for a project adopting the devkit:
  bootstrap with worked examples for a new and an existing repository, what to
  settle in the first ten minutes, daily work, and `/devkit-sync`.

### Fixed

- Re-running `bootstrap.sh` now keeps `DEVKIT_FORGE` and `DEVKIT_STACKS` in
  `.devkit/config.sh` in step with the flags it was given. Those two keys name
  the installed packs and are read by `/devkit-sync` to decide which files to
  compare, so a stale value did not merely misinform: a stack added by a second
  bootstrap run stayed invisible to every later sync. The rest of the file is
  still the project's and is never rewritten.
