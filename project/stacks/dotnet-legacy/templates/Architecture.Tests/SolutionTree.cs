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
                packages.ToList());
        }

        private static ProjectLocation LocationOf(string relativeDirectory)
        {
            var segments = relativeDirectory.Split('/');
            if (segments.Length == 1)
            {
                return ProjectLocation.Ui;
            }

            if (segments.Length != 2)
            {
                return ProjectLocation.Elsewhere;
            }

            switch (segments[0])
            {
                case "Core":
                    return ProjectLocation.Core;
                case "Tools":
                    return ProjectLocation.Tools;
                case "Tests":
                    return ProjectLocation.Tests;
                default:
                    return ProjectLocation.Elsewhere;
            }
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
