# AGENTS.dotnet-legacy.md

Rules for a repository on **.NET Framework** — 4.8 and the versions before it,
built with MSBuild rather than the `dotnet` CLI. They add to
[`AGENTS.dotnet.md`](AGENTS.dotnet.md), which holds everything that is true of
.NET whatever the runtime, and through it to
[`AGENTS.core.md`](AGENTS.core.md). Neither is contradicted here.

For .NET 5 and later, see the `dotnet-core` pack. The two never ship together.

> **This pack has been run against one repository layout so far**: an ASP.NET
> MVC application with a unit test project on .NET Framework 4.8, created from
> the Visual Studio templates, with `packages.config`, and built with MSBuild
> and VSTest from Visual Studio 2026. Treat a failure in `.devkit/gates.sh` on
> a different layout as a gap in this pack, not in the project, and fix it
> upstream.

Managed by [raisr/devkit](https://github.com/raisr/devkit) — change them there,
not here. Deviations go in the *Deviations* table of the project `AGENTS.md`.

## Target and language version {#dotnet-legacy.targets}

A property lives where it takes effect. MSBuild imports `Directory.Build.props`
at the top of an old-style project file, so a value the project file sets for
itself always wins over it.

- `<TargetFrameworkVersion>` stays in each project file, where Visual Studio
  writes it and writes it back when the target is changed. Every project in the
  repository targets the same version; one that targets another is a deviation
  and needs a reason.
- `<LangVersion>` is decided once for the repository in `Directory.Build.props`.
  No project file sets it, so the value there takes effect. A project file that
  sets it for itself is a deviation and needs a reason.
- There is no version number in `Directory.Build.props`: an old-style project
  takes it from `Properties/AssemblyInfo.cs`.

**`LangVersion` is `7.3`, not `latest`.** It is the highest version Microsoft
supports on .NET Framework. The compiler will accept later syntax, but several
features quietly need types the Framework BCL does not have — records want
`IsExternalInit`, index and range want `Index`/`Range`, and the shims people
paste in to get around that are a maintenance liability. Where a later feature
is genuinely needed, raise the version deliberately and record it, rather than
discovering it through a build that works on one machine.

## Compiler settings {#dotnet-legacy.compiler}

Keep `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>` switched on. A
warning that is worth suppressing is worth suppressing explicitly, at the
narrowest scope, with a reason.

**Nullable reference types are off by default here**, and switching them on is
a per-project decision, not a repository rule. The Framework BCL carries no
nullability annotations, so an enabled project warns about the framework rather
than about its own code — the opposite of what the switch is for.

## Language style {#dotnet-legacy.style}

`.editorconfig` is the source of truth for style, exactly as in the other .NET
packs. What does not apply here, because the language version does not reach
it: file-scoped namespaces, primary constructors, records.

A DTO or command is therefore a `sealed class` whose properties are get-only
and set in the constructor. Immutability is the point of the rule; `record` was
only ever the shortest way to write it.

## Logging {#dotnet-legacy.logging}

Structured logging with named placeholders, never string interpolation inside
the template and never `Console.WriteLine`:

```csharp
logger.Info("Order {OrderId} shipped", id);
```

Which library provides it is a project decision — `Microsoft.Extensions.Logging`
runs on .NET Framework through `netstandard2.0`, and log4net and NLog are the
usual alternatives in an older codebase. The rule is the shape of the call, not
the package. User-facing console output, such as a startup banner, is not
logging and is the one exception.

## Configuration {#dotnet-legacy.configuration}

Configuration is read **once**, at the composition root, into a typed settings
object that the rest of the code receives through its constructor. No
`ConfigurationManager.AppSettings[...]` from the middle of a use case, and no
magic strings scattered around — that is the same rule as `IOptions<T>` states
in `dotnet-core`, with the mechanism of its time.

`web.config` and `app.config` hold no secrets. A transform that injects them at
deployment does not change that: the file in the repository carries a
placeholder.

## Gates {#dotnet-legacy.gates}

| Gate | Command | Expected |
|---|---|---|
| restore | `msbuild <solution> -t:restore -p:RestorePackagesConfig=true` | packages resolved, `packages.config` included |
| build | `msbuild <solution> -warnaserror` | 0 warnings, 0 errors |
| test | `vstest.console.exe` once per built test assembly, with `RunConfiguration.TreatNoTestsAsError=true` | green, and no assembly without a test |

They live in `.devkit/gates.sh`, which the project owns and adapts. Where the
repository drives its build through something else, `gates.sh` calls into that
rather than restating the build — one definition, not two that drift. Which
gates must pass is the rule here; how they are invoked is the project's.

**The `test` gate carries the architecture tests.** The pack installs
`src/Tests/Architecture.Tests/`, the project `dotnet.layout` makes mandatory,
as a template: an old-style project with `packages.config`, on MSTest 2.2.10.
MSTest rather than xUnit because the Visual Studio template for .NET Framework
uses it, and because xUnit 2.x on .NET Framework pulls `NETStandard.Library`
and its forty-odd packages into `packages.config`. Bootstrap does not edit the
solution, so the project is added once by hand — until it is, the gate passes
without running it:

```bash
dotnet sln add src/Tests/Architecture.Tests/Architecture.Tests.csproj
```

Its package paths assume the solution in the repository root and NuGet's
default `packages/` folder beside it. The tests read the `.csproj` files and
`packages.config` rather than the built assemblies, and find the repository
root by its `.git`.

**There is no format gate.** `dotnet format` needs SDK-style project files and
will not run over an old-style `.csproj`. The `.editorconfig` still binds and
the IDE still applies it; what enforces it in the build are the analyser
severities, which is why the ones that matter stand at `warning` rather than
`suggestion`. A repository that converts its projects to SDK-style gets the
format gate back and should take it.
