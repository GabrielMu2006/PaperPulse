using PaperPulse.Storage;
using Windows.Security.Credentials;

namespace PaperPulse.Windows;

public sealed class WindowsPasswordVaultCredentialStore : ICredentialStore
{
    private const string Resource = "com.gabrielmu.PaperPulse.windows";
    private readonly PasswordVault vault = new();

    public Task<string?> GetAsync(string account, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        try
        {
            PasswordCredential credential = vault.Retrieve(Resource, account);
            credential.RetrievePassword();
            return Task.FromResult<string?>(credential.Password);
        }
        catch
        {
            return Task.FromResult<string?>(null);
        }
    }

    public async Task SetAsync(string account, string secret, CancellationToken cancellationToken = default)
    {
        await RemoveAsync(account, cancellationToken).ConfigureAwait(false);
        cancellationToken.ThrowIfCancellationRequested();
        vault.Add(new PasswordCredential(Resource, account, secret));
    }

    public Task RemoveAsync(string account, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        try { vault.Remove(vault.Retrieve(Resource, account)); }
        catch { }
        return Task.CompletedTask;
    }
}
