using System;
using System.Collections.Generic;
using System.Linq;

namespace Architecture.Tests
{
    /// <summary>One <c>.csproj</c> under <c>src/</c>, with what it references.</summary>
    internal sealed class ProjectFile
    {
        /// <param name="name">The file name without its extension.</param>
        /// <param name="relativeDirectory">The directory, relative to <c>src/</c>, with <c>/</c> as separator.</param>
        /// <param name="location">What the directory makes the project.</param>
        /// <param name="projectReferences">The names of the projects it references.</param>
        /// <param name="packageReferences">The names of the packages it references.</param>
        /// <param name="fileReferences">
        /// The assemblies it references by <c>HintPath</c>. One from the GAC, such
        /// as <c>System.Web</c>, carries no path and looks exactly like the BCL, so
        /// it is not among them.
        /// </param>
        internal ProjectFile(
            string name,
            string relativeDirectory,
            ProjectLocation location,
            IReadOnlyList<string> projectReferences,
            IReadOnlyList<string> packageReferences,
            IReadOnlyList<string> fileReferences)
        {
            Name = name;
            RelativeDirectory = relativeDirectory;
            Location = location;
            ProjectReferences = projectReferences;
            PackageReferences = packageReferences;
            FileReferences = fileReferences;
        }

        internal string Name { get; }

        internal string RelativeDirectory { get; }

        internal ProjectLocation Location { get; }

        internal IReadOnlyList<string> ProjectReferences { get; }

        internal IReadOnlyList<string> PackageReferences { get; }

        internal IReadOnlyList<string> FileReferences { get; }

        internal bool IsContracts => Name.EndsWith(".Contracts", StringComparison.Ordinal);

        internal bool IsDomain => Name.EndsWith(".Domain", StringComparison.Ordinal);

        internal bool IsApplication => Name.EndsWith(".Application", StringComparison.Ordinal);

        internal bool IsInfrastructure => Name.IndexOf(".Infrastructure", StringComparison.Ordinal) >= 0;

        internal bool IsLayer => IsContracts || IsDomain || IsApplication || IsInfrastructure;

        /// <summary>The project's own directory, the last segment of <see cref="RelativeDirectory"/>.</summary>
        internal string DirectoryName => RelativeDirectory.Split('/').Last();

        /// <summary>
        /// What the name has to start with under <c>dotnet.layout</c>: the solution
        /// name, then every grouping directory between <c>src/</c> and the project.
        /// </summary>
        internal string NamePrefix(string solutionName)
        {
            var segments = RelativeDirectory.Split('/');
            var grouping = segments.Take(segments.Length - 1);
            return string.Join(".", new[] { solutionName }.Concat(grouping)) + ".";
        }

        /// <summary>
        /// The name of the project a test project is named after under
        /// <c>dotnet.tests</c>, or <see langword="null"/> when the name carries
        /// neither <c>.Tests.Unit</c> nor <c>.Tests.Integration</c>.
        /// </summary>
        internal string ProjectUnderTest()
        {
            var suffixes = new[] { ".Tests.Unit", ".Tests.Integration" };
            var suffix = suffixes.FirstOrDefault(candidate => Name.EndsWith(candidate, StringComparison.Ordinal));
            return suffix == null ? null : Name.Substring(0, Name.Length - suffix.Length);
        }
    }
}
