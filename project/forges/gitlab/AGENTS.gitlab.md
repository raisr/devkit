# AGENTS.gitlab.md

How work is organised on GitLab: branches, commits, issues, merge requests and
the review loop. They add to [`AGENTS.core.md`](AGENTS.core.md) and never
contradict it.

Managed by [raisr/devkit](https://github.com/raisr/devkit) — change them there,
not here. Deviations go in the *Deviations* table of the project `AGENTS.md`.

How much of this applies depends on `DEVKIT_WORKFLOW` in `.devkit/config.sh`:
under `full` all of it does, under `light` only *Branches* and *Commits*.

Slugs are prefixed `forge.` rather than `gitlab.`, and the GitHub pack uses the
same ones — a repository that moves between forges keeps its recorded
deviations pointing at the same rules.

## Branches {#forge.branches}

```
feature/<ticket>-<short-description>
fix/<ticket>-<short-description>
```

Only these two prefixes. A `chore`, `docs` or `refactor` ticket still gets a
`feature/` branch, so the tooling parses the ticket number back out of the
branch name.

The slug is the lowercased title, words joined by `-`. The default branch
carries no ticket, by design.

## Commits {#forge.commits}

Conventional commit types: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`,
`chore:`.

```
<type>: <summary>[ (#<ticket>)]

- <change one>
- <change two>
```

- The whole first line is **at most 50 characters**, ticket suffix included. If
  it is tight, trim the summary, not the type.
- Append ` (#<ticket>)` when the branch carries one. When it does not, append
  nothing — never a placeholder.
- Second line empty. Then one `-` bullet per logical change, concise and
  technical, no trailing punctuation.
- Nothing else: no explanations, no emoji, no attribution footer, no session
  link. Inside the repository the Git history is the provenance
  (`core.signature`).

## Issues {#forge.issues}

Every change under `full` needs an issue first, in this schema:

**Title:** `<type>: <short imperative>`, with `<type>` one of `feat` `fix`
`refactor` `docs` `chore` — the same word as the label.

**Description:**

```markdown
## Description

What should be done, and why. Only what is known up front — no speculation.
Facts and decisions already taken.

## Non-goals

One or two lines on what is deliberately out of scope.

## Acceptance criteria / Definition of Done

- [ ] Each item verifiable by both the maintainer and the agent.
- [ ] Where possible a concrete command and its expected result.
- [ ] Checkable facts over prose ("file X exists and contains Y", not
      "X is set up correctly").

## Type

`<type>`
```

Plus the external-system signature from `core.signature`.

- **Only up-front knowledge.** What is discovered while working the ticket goes
  into a comment or a follow-up issue, never retro-fitted into the description.
- No estimates, no assignees, no milestone, no weight, and no label beyond the
  type unless asked for.
- Check the open issues for a near-duplicate before filing.

The **Acceptance criteria** is the contract being fulfilled. Read it in full
before writing code, and walk it box by box before calling the work done.

Issues are referenced as `#<iid>` — the project-internal number, not the global
issue id.

## Labels {#forge.labels}

The five type labels `feat` `fix` `refactor` `docs` `chore` carry the
conventional-commit meaning and are created per project. Group labels that
happen to be inherited are not used for the type.

## Merge requests {#forge.requests}

Opened against the default branch, titled like the commit
(`<type>: <summary> (#<issue>)`), labelled with the type, and assigned.

The description carries:

- **what** changed and **why**
- an **Evidence** block with the gate output
- a **Changelog** line naming the category the entry went under, or `n. a.`
  with the reason it was skipped
- any **deviation from the Definition of Done**, called out rather than hidden
- `Closes #<issue>`
- the external-system signature from `core.signature`

Do not set *delete source branch* or *squash* on the agent side — how the
request lands is the maintainer's decision.

## Changelog {#forge.changelog}

`CHANGELOG.md` follows [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/).

A user-visible change **requires** an entry under `## [Unreleased]` in the
right category (`Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`,
`Security`). Write it for a person reading release notes — what changed and why
it matters, not the commit subject.

Purely internal work with no user-visible effect — tests, tooling, CI,
documentation only — may skip the entry. When it is skipped, say so in one line
in the request description.

## Review loop {#forge.review}

The maintainer reviews in the merge request and comments there. For each round:
address every point, re-run the gates, commit, push, and reply on the request
naming the commit that resolved each point. Sign the reply.

A GitLab thread stays open until it is resolved; resolve only the threads you
actually addressed.

**The work is finished when the maintainer approves or merges the request** —
not when the gates pass. After the merge, delete the branch.
