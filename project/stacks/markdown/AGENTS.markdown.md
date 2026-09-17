# AGENTS.markdown.md

Rules for a repository whose product is **Markdown** — documentation, a
handbook, a specification, a knowledge base. They add to
[`AGENTS.core.md`](AGENTS.core.md) and never contradict it.

The pack is named for what the repository is written in, not for what it is
for, so it sits beside the other stack packs rather than above them. A
repository that ships code *and* documentation does not need it: `core.docs`
already binds there.

Managed by [raisr/devkit](https://github.com/raisr/devkit) — change them there,
not here. Deviations go in the *Deviations* table of the project `AGENTS.md`.

## Structure {#markdown.structure}

`core.docs` says which three places carry documentation and what each is for.
Here the whole repository is the third one, so:

- **One topic per file.** A document that needs a second H1 is two documents.
- `docs/README.md` is the index and carries **one row per document** under
  `docs/`. A document that is not in the index is a document nobody finds.
- A file is named for its topic in lowercase with hyphens — `using-devkit.md`,
  not `UsingDevkit.md`. The repository is read on case-sensitive file systems
  too.
- Directories under `docs/` are for a group of documents that genuinely belong
  together, not for one file each. Where a directory exists, it carries its own
  `README.md` index and the parent index points at that.

## Links {#markdown.links}

- **Links between documents in the repository are relative** — `../AGENTS.md`,
  never a URL to the forge. A relative link survives a fork, a rename of the
  project and reading the repository offline.
- Every relative link resolves to a file that exists. The `links` gate checks
  this; it is the one mistake that a reader hits and a writer never does.
- Link the document, not a heading inside it, unless the heading carries a
  stable identifier. Heading anchors are generated from the wording and break
  silently when the wording changes.
- No bare URLs in running text. Give the link a title that says where it goes.

## Style {#markdown.style}

- **ATX headings** (`## Heading`), never the underlined form. A document has
  **exactly one H1**, and it is the first heading in the file.
- Heading levels are not skipped: no H3 directly under an H1.
- A file with no heading at all is a fragment, not a document — an import stub,
  a snippet included elsewhere. The rule above does not reach it, and the
  `headings` gate leaves it alone.
- **Hard-wrap prose at 80 columns.** A paragraph on one long line shows up in a
  diff as one changed line, which makes a review of prose useless.
- Fenced code blocks carry a language tag, so they are highlighted and
  greppable.
- Tables are for facts with the same shape in every row. Prose that happens to
  have two parts is not a table.
- Write what is true now. A document does not carry a changelog of itself —
  that is what the Git history and `CHANGELOG.md` are for.

## Gates {#markdown.gates}

Three, all green before a commit, all runnable by hand:

| Gate | Checks | Expected |
|---|---|---|
| `links` | every relative link in a Markdown file | the target exists |
| `index` | `docs/` against `docs/README.md` | each file has a row, each row a file |
| `headings` | the heading structure of each document | one H1 and it is first, no skipped level |

They live in `.devkit/gates.sh`, which the project owns and adapts. They need
`git`, `find`, `awk` and `sed` and nothing else — a documentation repository is
cloned by people who do not have a toolchain installed, and a gate they cannot
run is a gate that does not bind them.

What the gates deliberately do not check is the prose: wrap width, tone and
whether a sentence is worth reading are a review's job, not a script's.
