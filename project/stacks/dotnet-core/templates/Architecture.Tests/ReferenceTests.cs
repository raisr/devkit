namespace Architecture.Tests;

/// <summary>
/// The reference graph of <c>dotnet.layout</c>: within a stack the arrow points
/// inwards, a stack reaches another only through its Contracts, and a UI is a
/// leaf that no other UI builds on.
/// </summary>
public sealed class ReferenceTests
{
    public sealed class Contracts
    {
        /// <summary>
        /// Every caller takes Contracts, so it takes nothing else with it - no
        /// package, no shared framework, and no project but Shared.Contracts.
        /// Shared.Contracts itself references nothing at all.
        /// </summary>
        [Fact]
        public void References_Nothing_But_Shared_Contracts()
        {
            var offenders = SolutionTree.Projects
                .Where(project => project.IsContracts)
                .SelectMany(project => project.PackageReferences
                    .Concat(project.FrameworkReferences)
                    .Concat(project.ProjectReferences
                        .Where(reference => project.IsSharedContracts || !Is(reference, target => target.IsSharedContracts)))
                    .Select(reference => $"{project.Name} -> {reference}"))
                .ToList();

            Assert.Empty(offenders);
        }
    }

    public sealed class Domain
    {
        [Fact]
        public void References_Nothing_But_Contracts_And_The_Listed_Exceptions()
        {
            var offenders = SolutionTree.Projects
                .Where(project => project.IsDomain)
                .SelectMany(project => project.ProjectReferences
                    .Where(reference => !Is(reference, target =>
                        (target.IsContracts && target.Stack == project.Stack) || target.IsSharedContracts))
                    .Concat(project.PackageReferences)
                    .Concat(project.FrameworkReferences)
                    .Except(DomainExceptions.Allowed)
                    .Select(reference => $"{project.Name} -> {reference}"))
                .ToList();

            Assert.Empty(offenders);
        }
    }

    public sealed class Application
    {
        [Fact]
        public void References_No_Project_But_Its_Domain_Contracts_And_Shared()
        {
            var offenders = Offenders(
                project => project.IsApplication,
                (project, target) =>
                    ((target.IsDomain || target.IsContracts) && target.Stack == project.Stack)
                    || target.Location == ProjectLocation.Shared);

            Assert.Empty(offenders);
        }
    }

    public sealed class Infrastructure
    {
        [Fact]
        public void References_No_Project_But_Its_Inner_Layers_Shared_And_Other_Contracts()
        {
            var offenders = Offenders(
                project => project.IsInfrastructure,
                (project, target) =>
                    ((target.IsApplication || target.IsDomain) && target.Stack == project.Stack)
                    || target.IsContracts
                    || target.Location == ProjectLocation.Shared);

            Assert.Empty(offenders);
        }
    }

    public sealed class Host
    {
        [Fact]
        public void References_No_Project_But_Its_Layers_Shared_The_Sdk_And_Other_Contracts()
        {
            var offenders = Offenders(
                project => project.IsHost,
                (project, target) =>
                    (target.IsLayer && target.Stack == project.Stack)
                    || target.IsContracts
                    || target.Location is ProjectLocation.Shared or ProjectLocation.Sdk);

            Assert.Empty(offenders);
        }
    }

    public sealed class Shared
    {
        [Fact]
        public void Library_References_No_Project_Outside_Shared()
        {
            var offenders = Offenders(
                project => project.IsSharedLibrary,
                (_, target) => target.Location == ProjectLocation.Shared);

            Assert.Empty(offenders);
        }
    }

    public sealed class Sdk
    {
        [Fact]
        public void References_No_Project_Outside_Shared()
        {
            var offenders = Offenders(
                project => project.Location == ProjectLocation.Sdk,
                (_, target) => target.Location == ProjectLocation.Shared);

            Assert.Empty(offenders);
        }
    }

    public sealed class Aspire
    {
        [Fact]
        public void App_Host_References_No_Project_But_Hosts_Uis_And_Shared_Libraries()
        {
            var offenders = Offenders(
                project => project.Location == ProjectLocation.Aspire,
                (_, target) => target.IsHost || target.Location == ProjectLocation.Ui || target.IsSharedLibrary);

            Assert.Empty(offenders);
        }

        [Fact]
        public void App_Host_Is_Referenced_By_No_Production_Project()
        {
            var offenders = Offenders(
                project => project.Location != ProjectLocation.Tests,
                (_, target) => target.Location != ProjectLocation.Aspire);

            Assert.Empty(offenders);
        }
    }

    public sealed class Ui
    {
        [Fact]
        public void References_No_Other_Ui()
        {
            var offenders = Offenders(
                project => project.Location == ProjectLocation.Ui,
                (_, target) => target.Location != ProjectLocation.Ui);

            Assert.Empty(offenders);
        }
    }

    /// <summary>
    /// Every project reference, from a project <paramref name="from"/> selects,
    /// that <paramref name="allowed"/> rejects for that project. A reference to
    /// a project outside <c>src/</c> is not in the tree and is never allowed.
    /// </summary>
    private static List<string> Offenders(Func<ProjectFile, bool> from, Func<ProjectFile, ProjectFile, bool> allowed)
    {
        return SolutionTree.Projects
            .Where(from)
            .SelectMany(project => project.ProjectReferences
                .Where(reference => !Is(reference, target => allowed(project, target)))
                .Select(reference => $"{project.Name} -> {reference}"))
            .ToList();
    }

    /// <summary>Whether the referenced project is in the tree and <paramref name="predicate"/> holds for it.</summary>
    private static bool Is(string reference, Func<ProjectFile, bool> predicate)
    {
        var target = SolutionTree.Projects.FirstOrDefault(project => project.Name == reference);
        return target is not null && predicate(target);
    }
}
