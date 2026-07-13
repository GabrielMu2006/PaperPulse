namespace PaperPulse.Storage;

public interface ICredentialStore
{
    Task<string?> GetAsync(string account, CancellationToken cancellationToken = default);
    Task SetAsync(string account, string secret, CancellationToken cancellationToken = default);
    Task RemoveAsync(string account, CancellationToken cancellationToken = default);
}

// The Windows project supplies the PasswordVault adapter; portable storage never persists secrets.
public sealed class InMemoryCredentialStore : ICredentialStore
{
    private readonly Dictionary<string, string> values = new(StringComparer.Ordinal);

    public Task<string?> GetAsync(string account, CancellationToken cancellationToken = default) => Task.FromResult(values.TryGetValue(account, out string? value) ? value : null);
    public Task SetAsync(string account, string secret, CancellationToken cancellationToken = default) { values[account] = secret; return Task.CompletedTask; }
    public Task RemoveAsync(string account, CancellationToken cancellationToken = default) { values.Remove(account); return Task.CompletedTask; }
}
