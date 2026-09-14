# AGENTS.dotnet.md

Rules that hold for any .NET repository, whichever runtime it targets. They add
to [`AGENTS.core.md`](AGENTS.core.md) and never contradict it — where this file
is silent, the core rule applies unchanged.

This file is **shared**: it is not a stack pack of its own and cannot be picked
with `--stack`. Both `dotnet-core` (net5 and later) and `dotnet-legacy` (.NET
Framework) install it, and each adds the rules that only hold for its runtime
in `AGENTS.dotnet-core.md` or `AGENTS.dotnet-legacy.md`.

Managed by [raisr/devkit](https://github.com/raisr/devkit) — change the rules
there, not here. Deviations go in the *Deviations* table of the project
`AGENTS.md`.

## Namespaces {#dotnet.namespaces}

**The namespace always follows the directory structure.** A file in
`src/Acme.Web/Configuration/` is in `Acme.Web.Configuration`, with no exception
for extension classes or anything else. The analyser enforces it (`IDE0130`),
so a mismatch fails the gate rather than surviving in review.

## Entry point {#dotnet.entry-point}

**No top-level statements.** The entry point is an ordinary `Program` class
with an explicit `Main`, in a namespace like every other type. The composition
root is the one place a newcomer reads first — it deserves a name, an XML doc
and a file that looks like the rest of the codebase.

## Async {#dotnet.async}

`async`/`await` end to end, and pass the `CancellationToken` through. No
`.Result`, no `.Wait()`, no `async void` except an event handler that the
framework demands.

## Dependency injection {#dotnet.di}

Constructor injection only. No service locator, no `new` on a service, no
static mutable state.

## Persistence {#dotnet.persistence}

The domain layer contains no attributes from the ORM or the web framework.
Persistence details live in configurations under the infrastructure project,
mapped onto plain models. The rules must be readable, and testable, without a
database.

## Web {#dotnet.web}

`[Authorize]` is the default on every endpoint; `[AllowAnonymous]` is a
justified exception, written down where it is used.

## Patterns we do not use {#dotnet.antipatterns}

In addition to the ones in `AGENTS.core.md`:

- `DateTime.Now` or `DateTime.UtcNow` in domain code. Inject a clock.
- `Task.Run` to make synchronous code look asynchronous.

## Tests {#dotnet.tests}

**A test project belongs to exactly one production project and is named
`<Project>.Tests.Unit` or `<Project>.Tests.Integration`.** It lives under
`src/Tests/`, and folder, `.csproj`, assembly name and root namespace all carry
that same name. A project gets a test project once it actually has tests — no
empty projects on stock.

Tests that assert solution-wide rules — such as which project may reference
which — belong to no single project and carry no `.Unit`/`.Integration`
suffix. That is the only exception; a second one needs a ticket that argues
for it.

**One test class per class under test, one nested class per method under
test:**

```csharp
public sealed class OrderServiceTests            // class under test
{
    public sealed class PlaceOrderAsync          // method under test
    {
        [Fact]
        public async Task Returns_Failure_When_Cart_Is_Empty() { }

        [Fact]
        public async Task Persists_Order_When_Cart_Is_Valid() { }
    }
}
```

- The test file mirrors the source path *inside its project*:
  `src/Acme.Application/Orders/OrderService.cs` becomes
  `src/Tests/Acme.Application.Tests.Unit/Orders/OrderServiceTests.cs`. The
  project name already says which project is under test, so it is not repeated
  as a folder.
- The method name reads `Scenario_ExpectedResult`. The method under test is
  already the nested class — do not repeat it.

## Dependencies {#dotnet.dependencies}

Check the BCL first. A NuGet package needs a reason that survives being said
out loud. No major-version upgrade without asking.

Package versions belong in the project files, which cannot go stale — not in
documentation.
