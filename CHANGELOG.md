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

## 2026-10-29

### Added

- **`dotnet.layout` has an optional Contracts layer.** What an application
  shares with its callers — request and response types, messages, a result
  type — had no place, and each type would have become a Domain exception.
  `<Name>.Core.Contracts` in `src/Core/` holds them and references nothing
  beyond the BCL, so a caller takes nothing else with it. Domain, Application
  and Infrastructure may reference it; it never references the Domain.
  `Architecture.Tests` asserts this, and in `dotnet-core` now also fails on a
  framework reference in Contracts or the Domain. The test files are
  templates, so a repository that already has them adopts the change by hand.

## 2026-10-27

### Added

- **`dotnet-core.web` makes HTTP APIs controllers.** ASP.NET Core offers
  controllers and minimal APIs, and the rules did not choose, so repositories
  drifted between the two. API endpoints are now `[ApiController]` classes
  with attribute routing. A repository that keeps minimal APIs records a
  deviation of `dotnet-core.web`. Endpoints the framework maps itself, such as
  `MapHealthChecks` and `MapOpenApi`, are unaffected.
- **`core.design` forbids magic strings and numbers.** The ban used to cover
  configuration only. A literal that carries meaning is now a named constant
  everywhere, and where the platform defines one, that one is used —
  `dotnet-core.style` names `HttpMethods`, `StatusCodes` and `MediaTypeNames`
  as examples. A literal in a test that states the expected wire format is
  exempt: it is the expectation, not a magic value.

## 2026-10-26

### Added

- **`/create-issue` sets the tickets a new one is blocked by.** It asks for the
  direct prerequisites while drafting, shows them with the draft, and records
  them after filing as the forge's own dependency links, through the new
  `forge_issue_block`. Picking "the next unblocked ticket" no longer needs the
  links set by hand. On GitLab the free tier has no blocking links; there the
  two tickets are linked as related instead, and the skill says so.

- **A template can be moved.** A template belongs to the project, but where it
  lived was always the manifest's say: a repository that moved
  `docs/architecture.md` into `docs/architecture/` saw `/devkit-sync` report it
  as `missing` on every run, and a bootstrap re-run wrote a fresh copy at the
  old path. Move the file and set the `path` of its entry in `devkit.lock.json`
  to the new place; sync and bootstrap both take the target from there. Managed
  files and blocks stay where the manifest puts them.

- **`Architecture.Tests` asserts test project names.** `dotnet.tests` has
  always required a test project to be named after one production project plus
  `.Tests.Unit` or `.Tests.Integration`, with `Architecture.Tests` as the one
  exception, but nothing checked it — a misnamed or orphaned test project
  passed every gate. A new test in `LayoutTests` names every project under
  `src/Tests/` that breaks the rule. It is a template: an existing repository
  copies `LayoutTests.cs` and `ProjectFile.cs` across by hand when
  `/devkit-sync` shows that they moved on.

### Changed

- **Breaking: grouping directories are part of a .NET project's name.**
  `dotnet.namespaces` says the namespace follows the directory structure, yet
  `dotnet.layout` put `<Name>.Domain` into `src/Core/` — so the stack pack
  broke its own rule for anyone reading it from `src/` on. A project is now
  named `<Name>`, then every grouping directory, then its own name:
  `src/Core/<Name>.Core.Domain/`, `src/Tools/<Name>.Tools.<Tool>/`. A UI
  directly under `src/` stays `<Name>.<Ui>`, and `src/Tests/` is not a segment —
  a test project is still named after the project under test. A repository on
  the old names either renames its projects, namespaces and test projects, or
  records a deviation against `dotnet.layout`. The `Architecture.Tests`
  template gains two tests that assert the names against the paths and the
  solution file; it is a template, so an existing repository copies
  `LayoutTests.cs`, `ProjectFile.cs` and `SolutionTree.cs` across by hand when
  `/devkit-sync` shows that they moved on.

## 2026-10-19

### Changed

- **`core.antipatterns` no longer bans events.** "Domain events" stood in the
  list of DDD building blocks never to be suggested, which also ruled out an
  ordinary event that records something that happened — inside a service or
  published between services through a broker. Such a repository had to record
  a deviation for a design that has nothing to do with DDD. The list now names
  value objects, aggregate roots and repositories-per-aggregate only, and says
  that events are allowed. A repository that recorded a deviation against
  `core.antipatterns` for events can drop it.

## 2026-10-18

### Added

- **`dotnet.layout` in the shared .NET rules.** `core.architecture` stated the
  dependency direction but no project cut and no directory layout, so every
  repository invented its own. The rule now fixes both for `dotnet-core` and
  `dotnet-legacy` alike: Domain, Application and Infrastructure under
  `src/Core/`, every UI directly under `src/` as a composition root without
  business logic, tools under `src/Tools/`, tests under `src/Tests/`, and the
  solution file in the repository root. A Domain reference beyond the BCL is
  allowed only when it runs in-process and is named in the project
  `AGENTS.md`, and `<Name>.Architecture.Tests` is mandatory to assert all of
  it. The rule describes the target state: a repository that does not meet it
  yet records the gap in its *Deviations* table.
- **`docs/architecture.md` as a core template.** The *Architecture* section of
  the `AGENTS.md` template already sent the project layout there, but nothing
  created the file, so every repository started it from nothing. Bootstrap now
  writes it once with three sections — *Projects*, *Directory layout* and *Why
  it is cut this way* — and `docs/README.md` lists it from the start. A
  repository that predates it sees it as `missing` in `/devkit-sync`.
- **Architecture tests as a `dotnet-core` template.** `dotnet.layout` made them
  mandatory with nothing to start from. Bootstrap now installs
  `src/Tests/Architecture.Tests/`, which reads the `.csproj` files and fails
  when Domain references anything not listed in `DomainExceptions.cs`, when
  Application or Infrastructure reach outwards, when one UI references
  another, when a project lies outside `src/Core/`, `src/Tools/`,
  `src/Tests/` and the top of `src/`, or when the solution is not in the
  repository root. Add it to the solution once by hand; bootstrap does not
  edit the solution.
- **The same architecture tests for `dotnet-legacy`.** The same checks under
  the same test names, as an old-style project with `packages.config` on
  MSTest 2.2.10 and C# 7.3, reading `packages.config` as well as the project
  files. MSTest, not xUnit: it is what the Visual Studio template for .NET
  Framework uses, and xUnit 2.x there drags `NETStandard.Library` and its
  dependency tree into `packages.config`.

### Changed

- **`dotnet.layout` names the test project `Architecture.Tests`**, without
  the `<Name>.` prefix, because a template cannot land at a path that depends
  on the solution's name. The Domain exceptions are listed in
  `DomainExceptions.cs` inside it, and the project `AGENTS.md` points there
  instead of restating them. A repository that already follows the rule
  renames its project, or records the old name as a deviation.

### Fixed

- **The `dotnet-legacy` `restore` gate restores `packages.config`.** It ran
  `msbuild -t:restore`, which only covers `PackageReference`, leaves a
  `packages.config` project untouched and still exits 0, so a fresh clone
  passed `restore` and then failed `build` on missing packages. It now passes
  `-p:RestorePackagesConfig=true`. `.devkit/gates.sh` is a template: an
  existing repository adds the flag by hand.
- **The `dotnet-legacy` `test` gate fails when a test assembly has no tests.**
  VSTest exits 0 when it discovers nothing — a missing adapter, an assembly
  that fails to load — so the gate was green while nothing ran. Each assembly
  now gets a run of its own with `RunConfiguration.TreatNoTestsAsError=true`.
  An existing repository copies the new `gate_test` by hand.

## 2026-10-17

### Added

- `forge_issue_edit` in both forge adapters. A ticket that was wrong when it
  was filed could only be corrected by calling `gh` or `glab` directly, which
  the rules call a bug — `forge_pr_edit` had the request side, nothing had the
  issue side. It is for the correction before work starts; a finding made while
  working a ticket still goes into `forge_issue_reply`, and `forge.issues` is
  unchanged.
- **A merged request ticks its ticket.** The Definition of Done was ticked box
  by box in the request, but the ticket kept every box empty, so a closed
  ticket read as an unfulfilled contract. After the merge, `forge.review` now
  syncs the checkbox state from the request into the ticket and lists every box
  left open in one comment with its reason. `forge.issues` names this as the
  one edit to the description after work starts; the wording of a criterion
  still never changes.
- **`DEVKIT_ASSIGN_ISSUES` in `.devkit/config.sh`.** A request was always
  assigned to `DEVKIT_ASSIGNEE`, a ticket never, and a repository that wanted
  its tickets assigned had to do it by hand after every filing. With `yes`,
  `create-issue` assigns each new ticket to `DEVKIT_ASSIGNEE` through a new
  optional argument on `forge_issue_create`. It starts on `no`, and a
  repository bootstrapped before the key existed reads as `no` too — add the
  line by hand to turn it on, since `config.sh` is a template sync never
  rewrites.
- **A request carries its issue's milestone.** `forge_pr_create` set none, so
  milestone and release views on the forge listed the issues but not the
  requests that closed them. `forge.requests` now requires the milestone of
  the closed issue, `forge_issue_milestone` reads it in both adapters, and
  `forge_pr_create` takes it as an optional last argument — an issue without a
  milestone still yields a request without one.
- **EF migrations count as generated code** in the shared .NET `.editorconfig`
  block, for both `dotnet-core` and `dotnet-legacy`. EF writes them with a BOM
  and a block-scoped namespace and rewrites them on every model change, so the
  `dotnet-core` format gate went red on a branch whose own code was clean.
  `**/Migrations/*.cs` is now `generated_code = true`. EF6's
  `Migrations/Configuration.cs` is the exception: people maintain its `Seed`
  method, so it stays under the style rules. On `dotnet-legacy` the build was
  never affected — code-style rules do not run in an old-style project's build
  — so there the change only quiets the editor. A repository that carries such
  a section locally can drop it after the sync.
- **A third-party notices gate for `dotnet-core`** (`dotnet-core.notices`).
  A repository that ships a distributable build owes the licences of the
  packages inside it: MIT and Apache-2.0 make the copyright notice and the
  licence text travelling with the software a condition. The pack now installs
  a generator, `.devkit/generate-third-party-notices.cs`, that writes
  `THIRD-PARTY-NOTICES.md` from what `dotnet publish` actually ships — its
  `deps.json`, per runtime identifier, including the .NET runtime of a
  self-contained build — with licence metadata from a pinned `nuget-license`.
  A fourth gate, `notices`, regenerates into a temporary file and fails when
  the committed one is stale. It is off until `NOTICES_PROJECT` in
  `.devkit/gates.sh` names the shipped project, so a library is not held to
  it. Needs the .NET 10 SDK. An existing repository is offered the generator,
  its overrides file and the licence texts by `/devkit-sync`; its own
  `gates.sh` is a template, so the gate itself is copied in by hand.

### Changed

- **Breaking: the target framework lives in the project file, in both .NET
  stack packs.** `dotnet-legacy.targets` and the central-properties rule in
  `dotnet-core.compiler` said the target framework was set once in
  `Directory.Build.props`. It never took effect: MSBuild imports that file
  before the project file's own properties, and every project Visual Studio or
  `dotnet new` creates sets the target framework itself, so the project file
  won — measured with `msbuild -getProperty`. The rules now say a property
  lives where it takes effect. The target framework (and on `dotnet-core`
  `Nullable` and `ImplicitUsings`) stays in each project file, all projects on
  the same value; `Directory.Build.props` keeps only what no project file sets.
  The `Directory.Build.props` templates drop the values that were dead, and the
  legacy one drops `<Version>`, which an old-style project takes from
  `AssemblyInfo.cs`. The slugs are unchanged. A repository that already moved
  these values out of its project files into `Directory.Build.props` has a
  working build but now departs from the rule: record it as a deviation, or
  move them back.
- **The GitLab adapter and the `dotnet-legacy` pack are no longer untried.**
  Both were written from a command surface and shipped with a warning saying
  so. Each has now run against a sample repository on GitLab — an ASP.NET Core
  application, and an ASP.NET MVC application on .NET Framework 4.8 from the
  Visual Studio templates — and the defects listed under *Fixed* came out of
  that run. The warnings in `forge.sh`, `AGENTS.dotnet-legacy.md` and the
  legacy `gates.sh` now say what was verified instead. The GitLab adapter
  reads glab's JSON output throughout and was verified with glab 1.117.0; an
  older glab may lack `--output json --jq`.

### Fixed

- **On GitLab, ticking a ticket after a merge no longer deletes its first
  heading.** `forge_issue_body` cut the body out of `glab issue view` at the
  first blank line, but glab ends its header with `--`, so the output started
  inside the body and lost `## Description`. Written back through
  `forge_issue_edit`, that loss became permanent. Both `forge_issue_body` and
  `forge_issue_milestone` now read glab's JSON output (`--output json --jq`),
  which returns the stored description unchanged.
- **On GitLab, `create-issue` sees the type labels that exist.**
  `forge_labels_list` printed the ID column of `glab label list` instead of
  the names, so every label was reported missing and the skill offered to
  create labels the repository already had. It now reads glab's JSON output.
- **On GitLab, `forge_issue_list_open` prints the contract format.** It passed
  glab's table through — and on an empty project a sentence — where the
  contract and the GitHub adapter print `<number>|<labels>|<title>`, one line
  per open issue and nothing when there is none.
- **On GitLab, `forge_pr_line_comments` prints only line comments.** It ran
  the same command as `forge_pr_comments` and printed the whole request —
  header, description and every comment — so a review round could not tell
  which comment belonged to which line. It now prints `<path>:<line>  <body>`
  for each comment on a diff line, read from glab's JSON output.
- **On GitLab, `forge_check`, `forge_issue_view`, `forge_pr_view` and
  `forge_pr_comments` print the contract format.** They passed glab's text
  view through. `forge_pr_comments` was the one that misled: it printed the
  request's description and system notes ahead of the comments, so the
  description read as one of them. All four now read glab's JSON output.
  GitLab has no review decision, so `review=` in `forge_pr_view` is its
  detailed merge status — `not_approved` while an approval is missing.
- **The `dotnet-legacy` test gate finds the test assembly Visual Studio
  names.** It looked for `*.Tests.*.dll`, which needs something between
  `.Tests.` and `.dll`, so it missed `Sample.Tests.dll` — the default for a
  test project created next to a .NET Framework application — and failed with
  "no built test assemblies found" on tests that built and passed. The pattern
  is `*.Tests.dll` now. A repository that already has the gate keeps its own
  copy, since `gates.sh` is a template: correct the pattern there by hand.
- **The `dotnet-legacy` test gate runs under Git Bash.** It passed `/nologo`
  to `vstest.console.exe`, and Git Bash turns an argument starting with `/`
  into a Windows path, so VSTest read `C:/Program Files/Git/nologo` as a test
  source and failed. The option is `--nologo` now, which VSTest accepts and
  Git Bash leaves alone. As with the pattern above, correct an existing copy
  of `gates.sh` by hand.
- **The `dotnet-legacy` test gate finds test assemblies named by
  `dotnet.tests` again.** The pattern change above, from `*.Tests.*.dll` to
  `*.Tests.dll`, made the gate miss `<Project>.Tests.Unit.dll` and
  `<Project>.Tests.Integration.dll` — the names the rule prescribes — so it
  found no tests in a repository that follows it. The gate now matches both
  patterns: the rule's names, and the suffix-free `*.Tests.dll` that is both
  the rule's one exception and the Visual Studio default. A copy of `gates.sh`
  that took the earlier correction needs this one too.

## 2026-09-21

### Fixed

- **`.gitattributes` is a devkit block now, not a managed file.** It was
  installed `managed`, so a bootstrap replaced the file whole and every line
  the repository had was gone — silently, and `managed` then forbade putting it
  back. A documentation repository lost the rules that kept its Office and
  diagram files out of text handling. `text=auto` guesses right for those most
  of the time, which is what made this the bad kind of bug: it did not fail, it
  waited.

  The devkit lines now sit between `# >>> devkit:core >>>` and
  `# <<< devkit:core <<<` at the top of the file, and everything below them is
  the project's. Git takes the last line that matches a path, so a project line
  under the block wins — the same resolution order `.editorconfig` and
  `.gitignore` already rely on.

  **What a repository bootstrapped before this has to do:** nothing, if it never
  edited `.gitattributes`. The next bootstrap recognises the devkit's own copy
  from the hash in `devkit.lock.json` and the block replaces it. If the file was
  edited, nothing is removed — the project's lines and the devkit's cannot be
  told apart from the outside — the block goes in above them, and the run prints
  a `MIGRATION` note naming the file. Keep your own lines and delete the devkit
  ones that are now below the block; left there they override it.

## 2026-09-18

### Added

- A **`markdown` stack pack**, for a repository whose product is prose rather
  than code — documentation, a handbook, a specification. Install it with
  `--stack markdown`. It brings `AGENTS.markdown.md` (one topic per file, how
  documents are indexed, relative links, ATX headings) and a `.devkit/gates.sh`
  with three gates: every relative link resolves to a file that exists, every
  document under `docs/` has a row in the index next to it, and every document
  has exactly one H1 with no level skipped under it.

  The gates need `git`, `find`, `awk` and `sed` and nothing else. A
  documentation repository is cloned by people who have no toolchain installed,
  and a gate they cannot run is a gate that does not bind them.

  Until now such a repository had to bootstrap without a stack, which works but
  leaves it with no `.devkit/gates.sh` at all — while `core.gates` requires one
  and `implement-feature` calls it. Leaving `--stack` off is still right for a
  repository built on something with no pack; it is no longer what a Markdown
  repository has to settle for.

### Fixed

- Bootstrap no longer ends with *"no .sln/.slnx found — set SLN in
  `.devkit/gates.sh` yourself"* when nothing it installed asks for a solution
  path. The note now follows the files rather than the flags: it appears only
  where an installed template really carries the placeholder, and it names that
  file. A repository on `--stack markdown`, or on no stack at all, is no longer
  sent to edit a key that was never there.

## 2026-09-16

### Added

- The fixture now proves what happens when two stacks set the **same**
  `.editorconfig` key: the stack named last on the `--stack` line wins, because
  blocks land in pack order and a later section overrides an earlier one. It was
  the case the block mechanism exists for and the one nothing had ever
  exercised, since no two shipped packs disagree about a key. If you install two
  stacks that overlap, the flag order is the decision — it is not arbitrary and
  it is now asserted in both directions.

- A `sync` gate. `collect.sh` is what every `/devkit-sync` decision is made
  from, and nothing checked that it reported the truth. It now has a test that
  builds its own upstream, provokes each situation — changed upstream, edited
  locally, changed on both sides, a block that lost its marker, a template that
  moved on, a template that is gone, an orphan — and asserts the columns. The
  judgement itself stays out of reach of a script; `test/README.md` says which
  two cases a human still walks.

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
