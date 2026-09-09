# AGENTS.core.md

Rules that hold in every repository, whatever it is built with and wherever it
is hosted. They are binding for humans and agents alike.

Managed by [raisr/devkit](https://github.com/raisr/devkit) — change them there,
not here. Where a project deliberately departs from a rule, the exception is
recorded in the *Deviations* table of its own `AGENTS.md`, not by editing this
file.

Section slugs (`{#core.…}`) are stable identifiers. A recorded deviation points
at one, so they survive rewording of the text beneath them.

## Working style {#core.working-style}

- **When something is unclear, ask instead of guessing. No answer beats a bad
  answer.** This outranks every other rule here.
- Anything touching more than one file: agree the approach first, then write
  code. A plan is what you will change and why, not an essay.
- Single-file, obvious changes: just make them.
- Work in small, individually reviewable steps. A large correct change nobody
  can review is worse than three small ones.
- Prefer the boring solution. Introduce a pattern only where it earns its
  complexity.
- Do not fix what nobody asked about. Mention it instead and let the maintainer
  decide whether it is worth a detour.
- **Verify before you claim.** Run the build, run the tests, read the file back.
  "Should work" is not a result.
- Keep the working tree reviewable: no stray scratch files, no reformatted
  files nobody touched.

## Language {#core.language}

Everything written into a repository is **English**: identifiers, comments, API
documentation, commit messages, branch names, tickets, request descriptions and
the documentation itself. Discussion may happen in any language; the repository
does not care what language was spoken.

## Documentation {#core.docs}

Three places, three roles. Keep them apart:

| Where | Role |
|---|---|
| `README.md` | First contact: what this is, why it exists, how to get it running, status, licence |
| `docs/` | Explanation and reference: how it works and why it was built that way. `docs/README.md` is the index, one line per document |
| `AGENTS.md` | Binding rules and conventions. **It prescribes, it does not describe** — explanatory prose belongs in `docs/`, and the file links to it |

**Documentation is part of the change.** When a change makes a document in
`docs/`, the `README.md` or `AGENTS.md` wrong, incomplete or misleading,
updating it belongs in the same branch and the same request — not in a
follow-up ticket. A change that leaves documentation contradicting the code is
not done.

Conversely: no documentation is written for something that does not exist yet.

## Architecture {#core.architecture}

- **The dependency arrow points inwards, never outwards.** The centre holds the
  models and the rules that operate on them and knows nothing about the outside
  world. Every layer around it may depend only on layers closer to the centre.
- Infrastructure is never referenced from the layers it serves. When a use case
  needs the database, the file system or the clock, it declares an interface
  and infrastructure implements it.
- Only a composition root may wire concrete infrastructure to a use case. Every
  other project that reaches for infrastructure is a design error.
- **Nothing outside the centre decides what is valid.** Guard clauses belong in
  the model, not in the controller.
- A second external source is a **new** project next to the existing one, not a
  change to the existing implementation. A heavy dependency stays contained in
  the one project that needs it.
- Where the rules can be asserted by a test, assert them. A reference-graph
  rule that only lives in prose is a rule that gets broken.
- **Do not weaken a layer rule to make something compile.** If the dependency
  direction is in the way, the design is wrong, not the rule.

## Design {#core.design}

- **The SOLID principles are mandatory, not aspirational** — single
  responsibility, open/closed, Liskov substitution, interface segregation,
  dependency inversion. A change that violates one may be rejected in review
  even when it compiles and the tests pass.
- The editor configuration in the repository root is binding and overrules any
  differing opinion.

### Patterns we do not use — never suggest them {#core.antipatterns}

- Exceptions as control flow for expected business outcomes. Use a result type.
- Static helpers that hold state; a service locator.
- DDD building blocks: value objects, domain events, aggregate roots,
  repositories-per-aggregate. Plain models and the rules that operate on them
  are enough.

## Tests {#core.tests}

- **New or changed logic without a test counts as unfinished**, even when
  nobody asked for one.
- A test project belongs to exactly one production project. A project gets a
  test project once it actually has tests — no empty projects on stock.
- Test files mirror the source path inside their project, so a reader finds the
  test from the source and back.
- One class under test per test class, one behaviour per test. Arrange, act,
  assert. No logic in the test itself.
- A test name says what happens and what is expected, not which method is being
  called — the structure already says that.
- Integration tests run against a throwaway database created for the run, never
  against a shared one.

## Security {#core.security}

- No secrets in the repository. Use the platform secret store locally,
  environment variables when deployed. Secrets never go into a log or a chat
  message either.
- No concatenated SQL. Parameterised queries or a query API only.
- Validate input on the server, encode output, use anti-forgery tokens on
  forms.
- Authorise every endpoint explicitly. An anonymous endpoint is a justified
  exception, not the default.
- No personal data in logs.

## Gates {#core.gates}

Every repository defines the checks that must pass before a commit, and makes
them runnable by a human in one command. They pass before anything is
committed — not afterwards, not in CI only.

A gate that is regularly skipped is either wrong or unnecessary. Fix it or
delete it; do not learn to ignore it.

## Git {#core.git}

- **Agents change files only.** No commit, no push, no branch, no request
  unless the maintainer asks for it.
- Where a change is large, say how it would be sliced into commits. Do not make
  them.
- Never rewrite published history.

## Boundaries {#core.boundaries}

- **Never** run a migration, a script or a write of any kind against a
  production system.
- No new dependency without justification — check whether the standard library
  already covers it.
- No major-version upgrade of an existing dependency without asking.
- Do not touch generated files.

## Personal notes {#core.local}

If `AGENTS.local.md` exists next to the project `AGENTS.md`, read it as well
and let it win on conflicts. It carries personal and machine-specific settings,
is git-ignored, and is never required for anyone else to work on the
repository.

## Signing AI-generated content {#core.signature}

When an agent creates content in **external** systems — issues, requests,
wikis, comments, boards — it must be recognisable as not typed by a human.
Append the signature, separated by `---`:

```markdown
---
🤖 *Claude was here. No hands, but opinions.*
*<YYYY-MM-DD>*
```

The wording is fixed — do not rephrase it per context, or it stops being
reliably searchable. Search term: **`Claude was here`**.

This does not apply to files inside the repository, nor to commit messages:
there the Git history is the provenance.

## Recording a deviation {#core.deviations}

A project may depart from a rule here. It does so openly:

1. A row in the *Deviations* table of the project `AGENTS.md`: which rule, what
   is done instead, and why.
2. An entry in `devkit.lock.json` naming the section slug and the devkit commit
   the decision was made against.

Both, or neither. A deviation that exists only in the code is a rule violation,
and a deviation recorded only in the lock file is invisible to the next person
who reads the rules.
