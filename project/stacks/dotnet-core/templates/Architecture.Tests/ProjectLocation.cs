namespace Architecture.Tests;

/// <summary>Where a project lives, which tells the tests what it is.</summary>
internal enum ProjectLocation
{
    /// <summary>
    /// <c>src/&lt;Stack&gt;/&lt;project&gt;/</c> or
    /// <c>src/&lt;Group&gt;/&lt;Stack&gt;/&lt;project&gt;/</c> - a layer or a host
    /// of one stack. <c>src/Core/</c> is the stack of a single-stack solution.
    /// </summary>
    Stack,

    /// <summary><c>src/Shared/&lt;project&gt;/</c> - Shared.Contracts or a Shared library.</summary>
    Shared,

    /// <summary><c>src/Sdk/&lt;project&gt;/</c> - the SDK.</summary>
    Sdk,

    /// <summary><c>src/Aspire/&lt;project&gt;/</c> - the Aspire app host (<c>dotnet-core.aspire</c>).</summary>
    Aspire,

    /// <summary><c>src/Tools/&lt;project&gt;/</c> - a development tool.</summary>
    Tools,

    /// <summary><c>src/Tests/&lt;project&gt;/</c> - a test project.</summary>
    Tests,

    /// <summary><c>src/&lt;project&gt;/</c> - a UI, and therefore a composition root.</summary>
    Ui,

    /// <summary>Anywhere else, which <c>dotnet.layout</c> does not allow.</summary>
    Elsewhere,
}
