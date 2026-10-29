using System;
using System.Collections.Generic;
using System.Linq;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace Architecture.Tests
{
    /// <summary>
    /// The reference graph of <c>dotnet.layout</c>: within a stack the arrow points
    /// inwards, a stack reaches another only through its Contracts, and a UI is a
    /// leaf that no other UI builds on.
    /// </summary>
    public sealed class ReferenceTests
    {
        [TestClass]
        public sealed class Contracts
        {
            /// <summary>
            /// Every caller takes Contracts, so it takes nothing else with it - no
            /// package, no assembly from a path, and no project but Shared.Contracts.
            /// Shared.Contracts itself references nothing at all. An assembly from
            /// the GAC, such as <c>System.Web</c>, is not detected: in the project
            /// file it looks exactly like the BCL.
            /// </summary>
            [TestMethod]
            public void References_Nothing_But_Shared_Contracts()
            {
                var offenders = SolutionTree.Projects
                    .Where(project => project.IsContracts)
                    .SelectMany(project => project.PackageReferences
                        .Concat(project.FileReferences)
                        .Concat(project.ProjectReferences
                            .Where(reference => project.IsSharedContracts || !Is(reference, target => target.IsSharedContracts)))
                        .Distinct()
                        .Select(reference => $"{project.Name} -> {reference}"))
                    .ToList();

                Assert.AreEqual(string.Empty, string.Join(Environment.NewLine, offenders));
            }
        }

        [TestClass]
        public sealed class Domain
        {
            [TestMethod]
            public void References_Nothing_But_Contracts_And_The_Listed_Exceptions()
            {
                var offenders = SolutionTree.Projects
                    .Where(project => project.IsDomain)
                    .SelectMany(project => project.ProjectReferences
                        .Where(reference => !Is(reference, target =>
                            (target.IsContracts && target.Stack == project.Stack) || target.IsSharedContracts))
                        .Concat(project.PackageReferences)
                        .Except(DomainExceptions.Allowed)
                        .Select(reference => $"{project.Name} -> {reference}"))
                    .ToList();

                Assert.AreEqual(string.Empty, string.Join(Environment.NewLine, offenders));
            }
        }

        [TestClass]
        public sealed class Application
        {
            [TestMethod]
            public void References_No_Project_But_Its_Domain_Contracts_And_Shared()
            {
                var offenders = Offenders(
                    project => project.IsApplication,
                    (project, target) =>
                        ((target.IsDomain || target.IsContracts) && target.Stack == project.Stack)
                        || target.Location == ProjectLocation.Shared);

                Assert.AreEqual(string.Empty, string.Join(Environment.NewLine, offenders));
            }
        }

        [TestClass]
        public sealed class Infrastructure
        {
            [TestMethod]
            public void References_No_Project_But_Its_Inner_Layers_Shared_And_Other_Contracts()
            {
                var offenders = Offenders(
                    project => project.IsInfrastructure,
                    (project, target) =>
                        ((target.IsApplication || target.IsDomain) && target.Stack == project.Stack)
                        || target.IsContracts
                        || target.Location == ProjectLocation.Shared);

                Assert.AreEqual(string.Empty, string.Join(Environment.NewLine, offenders));
            }
        }

        [TestClass]
        public sealed class Host
        {
            [TestMethod]
            public void References_No_Project_But_Its_Layers_Shared_The_Sdk_And_Other_Contracts()
            {
                var offenders = Offenders(
                    project => project.IsHost,
                    (project, target) =>
                        (target.IsLayer && target.Stack == project.Stack)
                        || target.IsContracts
                        || target.Location == ProjectLocation.Shared
                        || target.Location == ProjectLocation.Sdk);

                Assert.AreEqual(string.Empty, string.Join(Environment.NewLine, offenders));
            }
        }

        [TestClass]
        public sealed class Shared
        {
            [TestMethod]
            public void Library_References_No_Project_Outside_Shared()
            {
                var offenders = Offenders(
                    project => project.IsSharedLibrary,
                    (project, target) => target.Location == ProjectLocation.Shared);

                Assert.AreEqual(string.Empty, string.Join(Environment.NewLine, offenders));
            }
        }

        [TestClass]
        public sealed class Sdk
        {
            [TestMethod]
            public void References_No_Project_Outside_Shared()
            {
                var offenders = Offenders(
                    project => project.Location == ProjectLocation.Sdk,
                    (project, target) => target.Location == ProjectLocation.Shared);

                Assert.AreEqual(string.Empty, string.Join(Environment.NewLine, offenders));
            }
        }

        [TestClass]
        public sealed class Ui
        {
            [TestMethod]
            public void References_No_Other_Ui()
            {
                var offenders = Offenders(
                    project => project.Location == ProjectLocation.Ui,
                    (project, target) => target.Location != ProjectLocation.Ui);

                Assert.AreEqual(string.Empty, string.Join(Environment.NewLine, offenders));
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
            return target != null && predicate(target);
        }
    }
}
