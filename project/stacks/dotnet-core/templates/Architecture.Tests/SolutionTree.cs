using System.Xml.Linq;

namespace Architecture.Tests;

/// <summary>
/// The repository as the tests see it: its root, and every project file under
/// <c>src/</c>, read once.
/// </summary>
internal static class SolutionTree
{
    /// <summary>The SDK that brings no shared framework beyond the BCL.</summary>
    private const string PlainSdk = "Microsoft.NET.Sdk";

    /// <summary>A project directly in a reserved directory: <c>src/Shared/&lt;project&gt;</c>.</summary>
    private const int ReservedDepth = 2;

    /// <summary>A project in a grouped stack: <c>src/&lt;Group&gt;/&lt;Stack&gt;/&lt;project&gt;</c>.</summary>
    private const int MaxStackDepth = 3;

    /// <summary>The directories under <c>src/</c> that are not stack names.</summary>
    private static readonly Dictionary<string, ProjectLocation> ReservedDirectories = new(StringComparer.Ordinal)
    {
        ["Shared"] = ProjectLocation.Shared,
        ["Sdk"] = ProjectLocation.Sdk,
        ["Aspire"] = ProjectLocation.Aspire,
        ["Tools"] = ProjectLocation.Tools,
        ["Tests"] = ProjectLocation.Tests,
    };

    internal static readonly string Root = FindRoot();

    internal static readonly string Source = Path.Combine(Root, "src");

    internal static readonly IReadOnlyList<ProjectFile> Projects = ReadProjects();

    internal static IEnumerable<string> SolutionFiles(string directory, SearchOption searchOption)
    {
        return Directory.EnumerateFiles(directory, "*.slnx", searchOption)
            .Concat(Directory.EnumerateFiles(directory, "*.sln", searchOption))
            .Where(path => !IsBuildOutput(path));
    }

    /// <summary>
    /// The names of the solution files in the repository root. <c>dotnet.layout</c>
    /// wants one, and its name is the <c>&lt;Name&gt;</c> every project starts with.
    /// A <c>.sln</c> next to a <c>.slnx</c> of the same name counts once.
    /// </summary>
    internal static IReadOnlyList<string> SolutionNames()
    {
        return SolutionFiles(Root, SearchOption.TopDirectoryOnly)
            .Select(path => Path.GetFileNameWithoutExtension(path))
            .Distinct(StringComparer.Ordinal)
            .ToList();
    }

    /// <summary>
    /// Walks up from the test assembly to the directory holding <c>.git</c>. Not
    /// to the first solution file: one that wrongly sits in <c>src/</c> would be
    /// mistaken for the root, and the layout test could never see it.
    /// </summary>
    private static string FindRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null)
        {
            var git = Path.Combine(directory.FullName, ".git");
            if (Directory.Exists(git) || File.Exists(git))
            {
                return directory.FullName;
            }

            directory = directory.Parent;
        }

        throw new InvalidOperationException(
            $"No .git found above {AppContext.BaseDirectory}; the tests need the repository checkout.");
    }

    private static List<ProjectFile> ReadProjects()
    {
        return Directory.EnumerateFiles(Source, "*.csproj", SearchOption.AllDirectories)
            .Where(path => !IsBuildOutput(path))
            .Select(Read)
            .ToList();
    }

    private static ProjectFile Read(string path)
    {
        var directory = Path.GetRelativePath(Source, Path.GetDirectoryName(path)!).Replace('\\', '/');
        var document = XDocument.Load(path);

        return new ProjectFile(
            Path.GetFileNameWithoutExtension(path),
            directory,
            LocationOf(directory),
            Includes(document, "ProjectReference").Select(ProjectName).ToList(),
            Includes(document, "PackageReference").ToList(),
            Frameworks(document).ToList());
    }

    /// <summary>
    /// Every <c>FrameworkReference</c>, plus the project's SDK when it is not the
    /// plain one: <c>Microsoft.NET.Sdk.Web</c> brings ASP.NET Core without a
    /// <c>FrameworkReference</c> in the file.
    /// </summary>
    private static IEnumerable<string> Frameworks(XDocument document)
    {
        var sdk = (string?)document.Root?.Attribute("Sdk");
        string[] implicitFramework = sdk is null || sdk == PlainSdk ? [] : [sdk];

        return Includes(document, "FrameworkReference").Concat(implicitFramework);
    }

    /// <summary>
    /// A reserved directory holds its projects directly. Any other directory is
    /// a stack, or a group of stacks one level deep - never deeper.
    /// </summary>
    private static ProjectLocation LocationOf(string relativeDirectory)
    {
        var segments = relativeDirectory.Split('/');
        if (segments.Length == 1)
        {
            return ProjectLocation.Ui;
        }

        if (ReservedDirectories.TryGetValue(segments[0], out var reserved))
        {
            return segments.Length == ReservedDepth ? reserved : ProjectLocation.Elsewhere;
        }

        return segments.Length <= MaxStackDepth ? ProjectLocation.Stack : ProjectLocation.Elsewhere;
    }

    /// <summary>
    /// Matched by local name, so a project file that declares the MSBuild
    /// namespace is read the same as one that does not.
    /// </summary>
    private static IEnumerable<string> Includes(XDocument document, string element)
    {
        return document.Descendants()
            .Where(node => node.Name.LocalName == element)
            .Select(node => (string?)node.Attribute("Include"))
            .OfType<string>();
    }

    private static string ProjectName(string include)
    {
        return Path.GetFileNameWithoutExtension(include.Replace('\\', '/'));
    }

    private static bool IsBuildOutput(string path)
    {
        var segments = path.Replace('\\', '/').Split('/');
        return segments.Contains("bin") || segments.Contains("obj");
    }
}
