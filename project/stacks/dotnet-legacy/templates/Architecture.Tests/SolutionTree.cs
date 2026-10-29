using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Xml.Linq;

namespace Architecture.Tests
{
    /// <summary>
    /// The repository as the tests see it: its root, and every project file under
    /// <c>src/</c>, read once.
    /// </summary>
    internal static class SolutionTree
    {
        /// <summary>A project directly in a reserved directory: <c>src/Shared/&lt;project&gt;</c>.</summary>
        private const int ReservedDepth = 2;

        /// <summary>A project in a grouped stack: <c>src/&lt;Group&gt;/&lt;Stack&gt;/&lt;project&gt;</c>.</summary>
        private const int MaxStackDepth = 3;

        /// <summary>The directories under <c>src/</c> that are not stack names.</summary>
        private static readonly Dictionary<string, ProjectLocation> ReservedDirectories =
            new Dictionary<string, ProjectLocation>(StringComparer.Ordinal)
            {
                ["Shared"] = ProjectLocation.Shared,
                ["Sdk"] = ProjectLocation.Sdk,
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
        /// <paramref name="path"/> relative to <paramref name="basePath"/>, with
        /// <c>/</c> as separator. .NET Framework has no
        /// <c>Path.GetRelativePath</c>; every path here lies below its base.
        /// </summary>
        internal static string RelativeTo(string basePath, string path)
        {
            var prefix = basePath.TrimEnd('\\', '/') + Path.DirectorySeparatorChar;
            var relative = path.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)
                ? path.Substring(prefix.Length)
                : path;
            return relative.Replace('\\', '/');
        }

        /// <summary>
        /// Walks up from the test assembly to the directory holding <c>.git</c>. Not
        /// to the first solution file: one that wrongly sits in <c>src/</c> would be
        /// mistaken for the root, and the layout test could never see it.
        /// </summary>
        private static string FindRoot()
        {
            var directory = new DirectoryInfo(AppDomain.CurrentDomain.BaseDirectory);
            while (directory != null)
            {
                var git = Path.Combine(directory.FullName, ".git");
                if (Directory.Exists(git) || File.Exists(git))
                {
                    return directory.FullName;
                }

                directory = directory.Parent;
            }

            throw new InvalidOperationException(
                $"No .git found above {AppDomain.CurrentDomain.BaseDirectory}; the tests need the repository checkout.");
        }

        private static List<ProjectFile> ReadProjects()
        {
            return Directory.EnumerateFiles(Source, "*.csproj", SearchOption.AllDirectories)
                .Where(path => !IsBuildOutput(path))
                .Select(Read)
                .ToList();
        }

        /// <summary>
        /// Packages come from <c>packages.config</c> beside the project file and from
        /// any <c>PackageReference</c> in it, so a project half-way through the
        /// migration is read whole.
        /// </summary>
        private static ProjectFile Read(string path)
        {
            var projectDirectory = Path.GetDirectoryName(path);
            var directory = RelativeTo(Source, projectDirectory);
            var document = XDocument.Load(path);

            var packages = Attributes(document, "PackageReference", "Include");
            var packagesConfig = Path.Combine(projectDirectory, "packages.config");
            if (File.Exists(packagesConfig))
            {
                packages = packages.Concat(Attributes(XDocument.Load(packagesConfig), "package", "id"));
            }

            return new ProjectFile(
                Path.GetFileNameWithoutExtension(path),
                directory,
                LocationOf(directory),
                Attributes(document, "ProjectReference", "Include").Select(ProjectName).ToList(),
                packages.ToList(),
                FileReferences(document).ToList());
        }

        /// <summary>
        /// Every <c>Reference</c> with a <c>HintPath</c>, by its assembly name. A
        /// package from <c>packages.config</c> shows up here as well as among the
        /// packages.
        /// </summary>
        private static IEnumerable<string> FileReferences(XDocument document)
        {
            return document.Descendants()
                .Where(node => node.Name.LocalName == "Reference")
                .Where(node => node.Elements().Any(child => child.Name.LocalName == "HintPath"))
                .Select(node => (string)node.Attribute("Include"))
                .Where(include => include != null)
                .Select(include => include.Split(',')[0].Trim());
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

            ProjectLocation reserved;
            if (ReservedDirectories.TryGetValue(segments[0], out reserved))
            {
                return segments.Length == ReservedDepth ? reserved : ProjectLocation.Elsewhere;
            }

            return segments.Length <= MaxStackDepth ? ProjectLocation.Stack : ProjectLocation.Elsewhere;
        }

        /// <summary>
        /// Matched by local name, because an old-style project file declares the
        /// MSBuild namespace and an SDK-style one does not.
        /// </summary>
        private static IEnumerable<string> Attributes(XDocument document, string element, string attribute)
        {
            return document.Descendants()
                .Where(node => node.Name.LocalName == element)
                .Select(node => (string)node.Attribute(attribute))
                .Where(value => value != null);
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
}
