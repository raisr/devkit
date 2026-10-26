using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace Architecture.Tests
{
    /// <summary>
    /// The directory layout of <c>dotnet.layout</c>: the solution in the root, the
    /// application in <c>src/Core/</c>, every UI directly under <c>src/</c>.
    /// </summary>
    public sealed class LayoutTests
    {
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
            public void Lie_In_Core_Tools_Tests_Or_Directly_Under_Src()
            {
                var offenders = SolutionTree.Projects
                    .Where(project => project.Location == ProjectLocation.Elsewhere)
                    .Select(project => $"src/{project.RelativeDirectory}")
                    .ToList();

                Assert.AreEqual(string.Empty, string.Join(Environment.NewLine, offenders));
            }

            [TestMethod]
            public void Put_Every_Layer_In_Core()
            {
                var offenders = SolutionTree.Projects
                    .Where(project => project.IsLayer && project.Location != ProjectLocation.Core)
                    .Select(project => $"src/{project.RelativeDirectory}")
                    .ToList();

                Assert.AreEqual(string.Empty, string.Join(Environment.NewLine, offenders));
            }

            [TestMethod]
            public void Keep_Anything_But_Layers_Out_Of_Core()
            {
                var offenders = SolutionTree.Projects
                    .Where(project => project.Location == ProjectLocation.Core && !project.IsLayer)
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
            /// </summary>
            [TestMethod]
            public void Are_Named_After_The_Solution_And_Their_Grouping_Directories()
            {
                var solutions = SolutionTree.SolutionNames();
                Assert.AreEqual(1, solutions.Count, $"Solutions in the repository root: {string.Join(", ", solutions)}");
                var solution = solutions[0];

                var offenders = SolutionTree.Projects
                    .Where(project => project.Location == ProjectLocation.Core
                        || project.Location == ProjectLocation.Tools
                        || project.Location == ProjectLocation.Ui)
                    .Where(project => !project.Name.StartsWith(project.NamePrefix(solution), StringComparison.Ordinal))
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
    }
}
