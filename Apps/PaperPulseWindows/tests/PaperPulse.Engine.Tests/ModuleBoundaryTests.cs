using System.Reflection;
using PaperPulse.Engine;
using Xunit;

namespace PaperPulse.Engine.Tests;

public sealed class ModuleBoundaryTests
{
    [Fact]
    public void EngineDoesNotReferenceWinuiOrSqlite()
    {
        AssemblyName[] references = typeof(EngineAssemblyMarker).Assembly.GetReferencedAssemblies();

        Assert.DoesNotContain(references, reference => reference.Name == "Microsoft.UI.Xaml");
        Assert.DoesNotContain(references, reference => reference.Name == "Microsoft.Data.Sqlite");
    }
}
