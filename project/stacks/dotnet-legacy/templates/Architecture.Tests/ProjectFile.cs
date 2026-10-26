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
        internal ProjectFile(
            string name,
            string relativeDirectory,
            ProjectLocation location,
            IReadOnlyList<string> projectReferences,
            IReadOnlyList<string> packageReferences)
        {
            Name = name;
            RelativeDirectory = relativeDirectory;
            Location = location;
            ProjectReferences = projectReferences;
            PackageReferences = packageReferences;
        }

        internal string Name { get; }

        internal string RelativeDirectory { get; }

        internal ProjectLocation Location { get; }

        internal IReadOnlyList<string> ProjectReferences { get; }

        internal IReadOnlyList<string> PackageReferences { get; }

        internal bool IsDomain => Name.EndsWith(".Domain", StringComparison.Ordinal);

        internal bool IsApplication => Name.EndsWith(".Application", StringComparison.Ordinal);

        internal bool IsInfrastructure => Name.IndexOf(".Infrastructure", StringComparison.Ordinal) >= 0;

        internal bool IsLayer => IsDomain || IsApplication || IsInfrastructure;

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
    }
}
