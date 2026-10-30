namespace Architecture.Tests;

/// <summary>One <c>.csproj</c> under <c>src/</c>, with what it references.</summary>
/// <param name="Name">The file name without its extension.</param>
/// <param name="RelativeDirectory">The directory, relative to <c>src/</c>, with <c>/</c> as separator.</param>
/// <param name="Location">What the directory makes the project.</param>
/// <param name="ProjectReferences">The names of the projects it references.</param>
/// <param name="PackageReferences">The names of the packages it references.</param>
/// <param name="FrameworkReferences">
/// The shared frameworks it references, explicitly or through an SDK other than
/// the plain <c>Microsoft.NET.Sdk</c>.
/// </param>
internal sealed record ProjectFile(
    string Name,
    string RelativeDirectory,
    ProjectLocation Location,
    IReadOnlyList<string> ProjectReferences,
    IReadOnlyList<string> PackageReferences,
    IReadOnlyList<string> FrameworkReferences)
{
    /// <summary>
    /// A project in <c>src/Tests/</c>. It carries the name of the project under
    /// test, such as <c>Acme.Core.Infrastructure.Tests.Unit</c>, and is never a
    /// layer for that: <c>dotnet.layout</c> leaves test projects unrestricted.
    /// </summary>
    internal bool IsTest => Location == ProjectLocation.Tests;

    internal bool IsContracts => !IsTest && Name.EndsWith(".Contracts", StringComparison.Ordinal);

    internal bool IsDomain => !IsTest && Name.EndsWith(".Domain", StringComparison.Ordinal);

    internal bool IsApplication => !IsTest && Name.EndsWith(".Application", StringComparison.Ordinal);

    internal bool IsInfrastructure => !IsTest && Name.Contains(".Infrastructure", StringComparison.Ordinal);

    internal bool IsLayer => IsContracts || IsDomain || IsApplication || IsInfrastructure;

    /// <summary>Any project in a stack that is not a layer: an API, a worker.</summary>
    internal bool IsHost => Location == ProjectLocation.Stack && !IsLayer;

    /// <summary>The one Contracts every project may reference.</summary>
    internal bool IsSharedContracts => Location == ProjectLocation.Shared && IsContracts;

    internal bool IsSharedLibrary => Location == ProjectLocation.Shared && !IsContracts;

    /// <summary>
    /// The stack's directory relative to <c>src/</c>, such as <c>Core</c> or
    /// <c>Modules/Billing</c>, or <see langword="null"/> outside a stack.
    /// </summary>
    internal string? Stack => Location == ProjectLocation.Stack
        ? RelativeDirectory[..RelativeDirectory.LastIndexOf('/')]
        : null;

    /// <summary>The project's own directory, the last segment of <see cref="RelativeDirectory"/>.</summary>
    internal string DirectoryName => RelativeDirectory.Split('/')[^1];

    /// <summary>
    /// What the name has to start with under <c>dotnet.layout</c>: the solution
    /// name, then every grouping directory between <c>src/</c> and the project.
    /// </summary>
    internal string NamePrefix(string solutionName)
    {
        var grouping = RelativeDirectory.Split('/')[..^1];
        return string.Join('.', [solutionName, .. grouping]) + ".";
    }

    /// <summary>
    /// The name of the project a test project is named after under
    /// <c>dotnet.tests</c>, or <see langword="null"/> when the name carries
    /// neither <c>.Tests.Unit</c> nor <c>.Tests.Integration</c>.
    /// </summary>
    internal string? ProjectUnderTest()
    {
        string[] suffixes = [".Tests.Unit", ".Tests.Integration"];
        var suffix = suffixes.FirstOrDefault(candidate => Name.EndsWith(candidate, StringComparison.Ordinal));
        return suffix is null ? null : Name[..^suffix.Length];
    }
}
