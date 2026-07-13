using System.Security.Cryptography;
using System.Text;

namespace PaperPulse.Storage;

public sealed class PaperPulsePaths
{
    public PaperPulsePaths(string? rootDirectory = null)
    {
        RootDirectory = rootDirectory ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "PaperPulse");
    }

    public string RootDirectory { get; }
    public string DatabasePath => Path.Combine(RootDirectory, "PaperPulse.db");
    public string PdfDirectory => Path.Combine(RootDirectory, "PDFs");
    public string InterpretationDirectory => Path.Combine(RootDirectory, "Interpretations");
    public string LogDirectory => Path.Combine(RootDirectory, "Logs");

    public void EnsureCreated()
    {
        Directory.CreateDirectory(RootDirectory);
        Directory.CreateDirectory(PdfDirectory);
        Directory.CreateDirectory(InterpretationDirectory);
        Directory.CreateDirectory(LogDirectory);
    }
}

public sealed record class StoredFile(string RelativePath, long ByteCount, string Sha256);

public sealed class PaperFileStore(PaperPulsePaths paths)
{
    public async Task<StoredFile> WritePdfAsync(string stablePaperId, Stream content, CancellationToken cancellationToken = default)
    {
        paths.EnsureCreated();
        string filename = $"{SafeStem(stablePaperId)}.pdf";
        string destination = Path.Combine(paths.PdfDirectory, filename);
        string temporary = $"{destination}.{Guid.NewGuid():N}.tmp";
        try
        {
            await using (FileStream output = new(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None, 81920, useAsync: true))
            {
                await content.CopyToAsync(output, cancellationToken).ConfigureAwait(false);
            }
            File.Move(temporary, destination, overwrite: true);
            FileInfo info = new(destination);
            await using FileStream input = File.OpenRead(destination);
            string sha256 = Convert.ToHexString(await SHA256.HashDataAsync(input, cancellationToken).ConfigureAwait(false)).ToLowerInvariant();
            return new StoredFile(Path.Combine("PDFs", filename), info.Length, sha256);
        }
        finally
        {
            if (File.Exists(temporary)) File.Delete(temporary);
        }
    }

    public string ResolveRelativePath(string relativePath)
    {
        string root = Path.GetFullPath(paths.RootDirectory) + Path.DirectorySeparatorChar;
        string resolved = Path.GetFullPath(Path.Combine(paths.RootDirectory, relativePath));
        if (!resolved.StartsWith(root, StringComparison.Ordinal)) throw new InvalidOperationException("Storage path escapes the PaperPulse root.");
        return resolved;
    }

    private static string SafeStem(string value)
    {
        StringBuilder builder = new();
        foreach (char character in value)
        {
            builder.Append(char.IsLetterOrDigit(character) || character is '.' or '-' or '_' ? character : '_');
        }
        return builder.ToString().Trim('_') is { Length: > 0 } stem ? stem : "paper";
    }
}
