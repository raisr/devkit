# AGENTS.dotnet-core.md

Rules for a repository on **.NET 5 or later** — the SDK-style, cross-platform
runtime. They add to [`AGENTS.dotnet.md`](AGENTS.dotnet.md), which holds
everything that is true of .NET whatever the runtime, and through it to
[`AGENTS.core.md`](AGENTS.core.md). Neither is contradicted here.

For .NET Framework, see the `dotnet-legacy` pack. The two never ship together.

> **On the name.** ".NET Core" is a retired product name — it ended at 3.1, and
> net5 and later are officially just ".NET", so this pack names a platform its
> users do not run. That was argued and the maintainer chose the name anyway.
> Renaming it is a breaking change for every recorded deviation pointing at a
> `dotnet-core.` slug, so do not change it back without asking.

Managed by [raisr/devkit](https://github.com/raisr/devkit) — change them there,
not here. Deviations go in the *Deviations* table of the project `AGENTS.md`.

## Compiler settings {#dotnet-core.compiler}

Keep `<Nullable>enable</Nullable>` and `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>`
switched on. A warning that is worth suppressing is worth suppressing
explicitly, at the narrowest scope, with a reason.

Target framework, language version and version number are set once in
`Directory.Build.props`, not per project file.

## Language style {#dotnet-core.style}

**`.editorconfig` is the source of truth for style, not this section.** It is
binding (`core.design`), it ships with this pack, and `dotnet format` enforces
it. Restating a setting here would only give it a second place to drift. What
is meant to bind stands there at `warning`, which `TreatWarningsAsErrors` turns
into a build error; what stands at `suggestion` is a preference, and raising it
is a deliberate change to the block, not a sentence in this file.

What the file cannot express, and therefore belongs here:

- Records for DTOs and commands.

## Logging {#dotnet-core.logging}

Log through `ILogger<T>` with structured templates:

```csharp
logger.LogInformation("Order {OrderId} shipped", id);
```

No `Console.WriteLine`, and no string interpolation inside a log template — it
destroys the structure the template exists for. User-facing console output,
such as a startup banner, is not logging and is the one exception.

## Configuration {#dotnet-core.configuration}

Configuration through `IOptions<T>`. No magic strings scattered around, no
`IConfiguration` reached into from the middle of a use case.

## Gates {#dotnet-core.gates}

Three, all green before a commit, all runnable by hand:

| Gate | Command | Expected |
|---|---|---|
| build | `dotnet build <solution> -warnaserror` | 0 warnings, 0 errors |
| test | `dotnet test <solution>` | green |
| format | `dotnet format <solution> --verify-no-changes` | clean |

They live in `.devkit/gates.sh`, which the project owns and adapts.

`-warnaserror` is on the gate itself rather than left to
`TreatWarningsAsErrors` in a `Directory.Build.props` the project owns. It also
promotes the NuGet audit warnings, so a newly published advisory can turn the
build red without a code change. That is intended: a known-vulnerable package
is a reason not to commit.

`dotnet test` exits non-zero when a test project contains **no** tests. A new
test project needs at least one real test, not a placeholder.
