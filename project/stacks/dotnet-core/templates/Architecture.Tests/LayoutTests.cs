namespace Architecture.Tests;

/// <summary>
/// The directory layout of <c>dotnet.layout</c>: the solution in the root, the
/// layers in stacks, every UI directly under <c>src/</c>, and the reserved
/// directories holding only what they are reserved for.
/// </summary>
public sealed class LayoutTests
{
    /// <summary>The SDK's name after the solution name (<c>dotnet.layout</c>).</summary>
    private const string SdkSuffix = ".Sdk";

    /// <summary>The app host's name after the solution name (<c>dotnet-core.aspire</c>).</summary>
    private const string AppHostSuffix = ".Aspire.AppHost";

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
        public void Lie_In_A_Stack_A_Reserved_Directory_Or_Directly_Under_Src()
        {
            var offenders = SolutionTree.Projects
                .Where(project => project.Location == ProjectLocation.Elsewhere)
                .Select(project => $"src/{project.RelativeDirectory}")
                .ToList();

            Assert.Empty(offenders);
        }

        /// <summary>
        /// Shared.Contracts is the one layer-named project outside a stack. A
        /// Domain or Application in <c>src/Shared/</c> fails here.
        /// </summary>
        [Fact]
        public void Put_Every_Layer_In_A_Stack()
        {
            var offenders = SolutionTree.Projects
                .Where(project => project.IsLayer && project.Location != ProjectLocation.Stack && !project.IsSharedContracts)
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
        /// A stack's single host and the SDK carry the prefix without an own
        /// name, such as <c>&lt;Name&gt;.Sdk</c>.
        /// </summary>
        [Fact]
        public void Are_Named_After_The_Solution_And_Their_Grouping_Directories()
        {
            var solution = Assert.Single(SolutionTree.SolutionNames());

            var offenders = SolutionTree.Projects
                .Where(project => project.Location != ProjectLocation.Tests)
                .Where(project => !project.Name.StartsWith(project.NamePrefix(solution), StringComparison.Ordinal))
                .Where(project => !(project.Location is ProjectLocation.Stack or ProjectLocation.Sdk
                    && project.Name == project.NamePrefix(solution).TrimEnd('.')))
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

    public sealed class Stacks
    {
        /// <summary>
        /// A host named after its stack, without a suffix, stands for a stack
        /// without business rules. Once layers grow next to it, it takes one.
        /// </summary>
        [Fact]
        public void Keep_A_Host_Without_Suffix_Alone()
        {
            var solution = Assert.Single(SolutionTree.SolutionNames());

            var offenders = SolutionTree.Projects
                .Where(project => project.IsHost && project.Name == project.NamePrefix(solution).TrimEnd('.'))
                .Where(host => SolutionTree.Projects.Any(other => other.Stack == host.Stack && other.Name != host.Name))
                .Select(host => host.Name)
                .ToList();

            Assert.Empty(offenders);
        }
    }

    public sealed class Reserved
    {
        [Fact]
        public void Sdk_Holds_Only_The_Sdk()
        {
            var solution = Assert.Single(SolutionTree.SolutionNames());

            var offenders = SolutionTree.Projects
                .Where(project => project.Location == ProjectLocation.Sdk && project.Name != solution + SdkSuffix)
                .Select(project => $"{project.Name}, expected {solution}{SdkSuffix}")
                .ToList();

            Assert.Empty(offenders);
        }

        [Fact]
        public void Aspire_Holds_Only_The_App_Host()
        {
            var solution = Assert.Single(SolutionTree.SolutionNames());

            var offenders = SolutionTree.Projects
                .Where(project => project.Location == ProjectLocation.Aspire && project.Name != solution + AppHostSuffix)
                .Select(project => $"{project.Name}, expected {solution}{AppHostSuffix}")
                .ToList();

            Assert.Empty(offenders);
        }
    }
}
