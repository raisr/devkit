# AGENTS.dotnet.md

<!-- devkit: PLACEHOLDER. Content lands in step 2, extracted from CashPrism. -->

**Placeholder — no rules in force yet.**

This file will carry what is true for a .NET repository and nowhere else:
nullable and warnings-as-errors, file-scoped namespaces, namespace follows
folder, primary constructors, records for DTOs, no top-level statements,
`ILogger<T>` with structured templates, `IOptions<T>`, async end to end, and
the three gates (`dotnet build`, `dotnet test`, `dotnet format`).

The .NET-specific `.editorconfig` rules ship next to this file as an
`.editorconfig` block, not as prose.

Section slugs are prefixed `dotnet.`, e.g. `{#dotnet.async}`.

Managed file — change it in raisr/devkit, not in the repository that received it.
