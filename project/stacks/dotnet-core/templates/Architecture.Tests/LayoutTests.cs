namespace Architecture.Tests;

/// <summary>
/// The directory layout of <c>dotnet.layout</c>: the solution in the root, the
/// application in <c>src/Core/</c>, every UI directly under <c>src/</c>.
/// </summary>
public sealed class LayoutTests
{
    public sealed class Solution
    {
        [Fact]
        public void Lies_In_The_Repository_Root()
        {
            var inRoot = SolutionTree.SolutionFiles(SolutionTree.Root, SearchOption.TopDirectoryOnly);

            Assert.NotEmpty(inRoot);
        }

        [Fact]
        public void Has_No_Copy_Under_Src()
        {
            var underSource = SolutionTree.SolutionFiles(SolutionTree.Source, SearchOption.AllDirectories)
                .Select(path => Path.GetRelativePath(SolutionTree.Root, path))
                .ToList();

            Assert.Empty(underSource);
        }
    }

    public sealed class Projects
    {
        [Fact]
        public void Lie_In_Core_Tools_Tests_Or_Directly_Under_Src()
        {
            var offenders = SolutionTree.Projects
                .Where(project => project.Location == ProjectLocation.Elsewhere)
                .Select(project => $"src/{project.RelativeDirectory}")
                .ToList();

            Assert.Empty(offenders);
        }

        [Fact]
        public void Put_Every_Layer_In_Core()
        {
            var offenders = SolutionTree.Projects
                .Where(project => project.IsLayer && project.Location != ProjectLocation.Core)
                .Select(project => $"src/{project.RelativeDirectory}")
                .ToList();

            Assert.Empty(offenders);
        }

        [Fact]
        public void Keep_Anything_But_Layers_Out_Of_Core()
        {
            var offenders = SolutionTree.Projects
                .Where(project => project.Location == ProjectLocation.Core && !project.IsLayer)
                .Select(project => $"src/{project.RelativeDirectory}")
                .ToList();

            Assert.Empty(offenders);
        }

        [Fact]
        public void Carry_The_Name_Of_Their_Directory()
        {
            var offenders = SolutionTree.Projects
                .Where(project => project.Name != project.DirectoryName)
                .Select(project => $"src/{project.RelativeDirectory}/{project.Name}.csproj")
                .ToList();

            Assert.Empty(offenders);
        }

        /// <summary>
        /// <c>src/Tests/</c> is left out: it is not a name segment, and a test
        /// project is named after the project under test (<c>dotnet.tests</c>).
        /// </summary>
        [Fact]
        public void Are_Named_After_The_Solution_And_Their_Grouping_Directories()
        {
            var solution = Assert.Single(SolutionTree.SolutionNames());

            var offenders = SolutionTree.Projects
                .Where(project => project.Location is ProjectLocation.Core or ProjectLocation.Tools or ProjectLocation.Ui)
                .Where(project => !project.Name.StartsWith(project.NamePrefix(solution), StringComparison.Ordinal))
                .Select(project => $"{project.Name}, expected {project.NamePrefix(solution)}*")
                .ToList();

            Assert.Empty(offenders);
        }

        /// <summary>
        /// <c>dotnet.tests</c>: a test project is named after exactly one
        /// production project, plus <c>.Tests.Unit</c> or <c>.Tests.Integration</c>.
        /// <c>Architecture.Tests</c> is the one solution-wide exception.
        /// </summary>
        [Fact]
        public void Under_Tests_Are_Named_After_A_Production_Project()
        {
            var production = SolutionTree.Projects
                .Where(project => project.Location != ProjectLocation.Tests)
                .Select(project => project.Name)
                .ToHashSet(StringComparer.Ordinal);

            var offenders = SolutionTree.Projects
                .Where(project => project.Location == ProjectLocation.Tests && project.Name != "Architecture.Tests")
                .Where(project => project.ProjectUnderTest() is not { } underTest || !production.Contains(underTest))
                .Select(project => project.Name)
                .ToList();

            Assert.Empty(offenders);
        }
    }
}
