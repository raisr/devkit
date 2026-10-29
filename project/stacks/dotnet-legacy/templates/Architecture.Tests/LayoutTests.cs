using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace Architecture.Tests
{
    /// <summary>
    /// The directory layout of <c>dotnet.layout</c>: the solution in the root, the
    /// layers in stacks, every UI directly under <c>src/</c>, and the reserved
    /// directories holding only what they are reserved for.
    /// </summary>
    public sealed class LayoutTests
    {
        /// <summary>The SDK's name after the solution name (<c>dotnet.layout</c>).</summary>
        private const string SdkSuffix = ".Sdk";

        [TestClass]
        public sealed class Solution
        {
            [TestMethod]
            public void Lies_In_The_Repository_Root()
            {
                var inRoot = SolutionTree.SolutionFiles(SolutionTree.Root, SearchOption.TopDirectoryOnly);

                Assert.IsTrue(inRoot.Any(), $"No .sln or .slnx in {SolutionTree.Root}");
            }

            [TestMethod]
            public void Has_No_Copy_Under_Src()
            {
                var underSource = SolutionTree.SolutionFiles(SolutionTree.Source, SearchOption.AllDirectories)
                    .Select(path => SolutionTree.RelativeTo(SolutionTree.Root, path))
                    .ToList();

                Assert.AreEqual(string.Empty, string.Join(Environment.NewLine, underSource));
            }
        }

        [TestClass]
        public sealed class Projects
        {
            [TestMethod]
            public void Lie_In_A_Stack_A_Reserved_Directory_Or_Directly_Under_Src()
            {
                var offenders = SolutionTree.Projects
                    .Where(project => project.Location == ProjectLocation.Elsewhere)
                    .Select(project => $"src/{project.RelativeDirectory}")
                    .ToList();

                Assert.AreEqual(string.Empty, string.Join(Environment.NewLine, offenders));
            }

            /// <summary>
            /// Shared.Contracts is the one layer-named project outside a stack. A
            /// Domain or Application in <c>src/Shared/</c> fails here.
            /// </summary>
            [TestMethod]
            public void Put_Every_Layer_In_A_Stack()
            {
                var offenders = SolutionTree.Projects
                    .Where(project => project.IsLayer && project.Location != ProjectLocation.Stack && !project.IsSharedContracts)
                    .Select(project => $"src/{project.RelativeDirectory}")
                    .ToList();

                Assert.AreEqual(string.Empty, string.Join(Environment.NewLine, offenders));
            }

            [TestMethod]
            public void Carry_The_Name_Of_Their_Directory()
            {
                var offenders = SolutionTree.Projects
                    .Where(project => project.Name != project.DirectoryName)
                    .Select(project => $"src/{project.RelativeDirectory}/{project.Name}.csproj")
                    .ToList();

                Assert.AreEqual(string.Empty, string.Join(Environment.NewLine, offenders));
            }

            /// <summary>
            /// <c>src/Tests/</c> is left out: it is not a name segment, and a test
            /// project is named after the project under test (<c>dotnet.tests</c>).
            /// A stack's single host and the SDK carry the prefix without an own
            /// name, such as <c>&lt;Name&gt;.Sdk</c>.
            /// </summary>
            [TestMethod]
            public void Are_Named_After_The_Solution_And_Their_Grouping_Directories()
            {
                var solution = SingleSolution();

                var offenders = SolutionTree.Projects
                    .Where(project => project.Location != ProjectLocation.Tests)
                    .Where(project => !project.Name.StartsWith(project.NamePrefix(solution), StringComparison.Ordinal))
                    .Where(project => !((project.Location == ProjectLocation.Stack || project.Location == ProjectLocation.Sdk)
                        && project.Name == project.NamePrefix(solution).TrimEnd('.')))
                    .Select(project => $"{project.Name}, expected {project.NamePrefix(solution)}*")
                    .ToList();

                Assert.AreEqual(string.Empty, string.Join(Environment.NewLine, offenders));
            }

            /// <summary>
            /// <c>dotnet.tests</c>: a test project is named after exactly one
            /// production project, plus <c>.Tests.Unit</c> or <c>.Tests.Integration</c>.
            /// <c>Architecture.Tests</c> is the one solution-wide exception.
            /// </summary>
            [TestMethod]
            public void Under_Tests_Are_Named_After_A_Production_Project()
            {
                var production = new HashSet<string>(
                    SolutionTree.Projects
                        .Where(project => project.Location != ProjectLocation.Tests)
                        .Select(project => project.Name),
                    StringComparer.Ordinal);

                var offenders = SolutionTree.Projects
                    .Where(project => project.Location == ProjectLocation.Tests && project.Name != "Architecture.Tests")
                    .Where(project => project.ProjectUnderTest() == null || !production.Contains(project.ProjectUnderTest()))
                    .Select(project => project.Name)
                    .ToList();

                Assert.AreEqual(string.Empty, string.Join(Environment.NewLine, offenders));
            }
        }

        [TestClass]
        public sealed class Stacks
        {
            /// <summary>
            /// A host named after its stack, without a suffix, stands for a stack
            /// without business rules. Once layers grow next to it, it takes one.
            /// </summary>
            [TestMethod]
            public void Keep_A_Host_Without_Suffix_Alone()
            {
                var solution = SingleSolution();

                var offenders = SolutionTree.Projects
                    .Where(project => project.IsHost && project.Name == project.NamePrefix(solution).TrimEnd('.'))
                    .Where(host => SolutionTree.Projects.Any(other => other.Stack == host.Stack && other.Name != host.Name))
                    .Select(host => host.Name)
                    .ToList();

                Assert.AreEqual(string.Empty, string.Join(Environment.NewLine, offenders));
            }
        }

        [TestClass]
        public sealed class Reserved
        {
            [TestMethod]
            public void Sdk_Holds_Only_The_Sdk()
            {
                var solution = SingleSolution();

                var offenders = SolutionTree.Projects
                    .Where(project => project.Location == ProjectLocation.Sdk && project.Name != solution + SdkSuffix)
                    .Select(project => $"{project.Name}, expected {solution}{SdkSuffix}")
                    .ToList();

                Assert.AreEqual(string.Empty, string.Join(Environment.NewLine, offenders));
            }
        }

        private static string SingleSolution()
        {
            var solutions = SolutionTree.SolutionNames();
            Assert.AreEqual(1, solutions.Count, $"Solutions in the repository root: {string.Join(", ", solutions)}");
            return solutions[0];
        }
    }
}
