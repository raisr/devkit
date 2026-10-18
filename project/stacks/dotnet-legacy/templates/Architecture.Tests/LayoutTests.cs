using System;
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
        }
    }
}
