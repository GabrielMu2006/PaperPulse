using System.Reflection;
using PaperPulse.Storage;
using Xunit;

namespace PaperPulse.Storage.Tests;

public sealed class ModuleBoundaryTests
{
    [Fact]
    public void StorageDoesNotReferenceWinui()
    {
        AssemblyName[] references = typeof(StorageAssemblyMarker).Assembly.GetReferencedAssemblies();

        Assert.DoesNotContain(references, reference => reference.Name == "Microsoft.UI.Xaml");
    }
}
