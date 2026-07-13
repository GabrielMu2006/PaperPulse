using System.Security.Cryptography;
using PaperPulse.Contracts;

namespace PaperPulse.Engine;

public enum PaperPdfDownloadFailure
{
    MissingPdfUrl,
    UnverifiedOpenAccess,
    InsecureUrl,
    HttpStatus,
    InvalidMimeType,
    FileTooSmall,
    FileTooLarge,
    InvalidPdfSignature
}

public sealed class PaperPdfDownloadException(PaperPdfDownloadFailure failure, string message) : Exception(message)
{
    public PaperPdfDownloadFailure Failure { get; } = failure;
}

public sealed record DownloadedPaperPdf(byte[] Content, string Sha256, string MimeType);

public sealed class PaperPdfDownloader
{
    private static readonly byte[] PdfSignature = "%PDF"u8.ToArray();

    private readonly IHttpTransport transport;
    private readonly int minimumBytes;
    private readonly int maximumBytes;

    public PaperPdfDownloader(IHttpTransport transport, int minimumBytes = 10_000, int maximumBytes = 100 * 1024 * 1024)
    {
        this.transport = transport;
        this.minimumBytes = Math.Max(0, minimumBytes);
        this.maximumBytes = Math.Max(this.minimumBytes, maximumBytes);
    }

    public async Task<DownloadedPaperPdf> DownloadAsync(PaperCandidate paper, CancellationToken cancellationToken = default)
    {
        Uri source = ResolveVerifiedUrl(paper);
        using HttpRequestMessage request = new(HttpMethod.Get, source);
        request.Headers.UserAgent.ParseAdd("PaperPulse/1.0");
        HttpResponse response = await transport.SendAsync(request, cancellationToken).ConfigureAwait(false);

        if (response.StatusCode is < 200 or >= 300)
        {
            throw new PaperPdfDownloadException(PaperPdfDownloadFailure.HttpStatus, $"PDF download returned HTTP {response.StatusCode}.");
        }
        if (!string.Equals(response.FinalUri.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase))
        {
            throw new PaperPdfDownloadException(PaperPdfDownloadFailure.InsecureUrl, "PDF download redirected to an insecure URL.");
        }
        if (!string.IsNullOrWhiteSpace(response.MimeType) && !response.MimeType.Contains("pdf", StringComparison.OrdinalIgnoreCase))
        {
            throw new PaperPdfDownloadException(PaperPdfDownloadFailure.InvalidMimeType, $"Expected a PDF response, received {response.MimeType}.");
        }
        if (response.Data.Length < minimumBytes)
        {
            throw new PaperPdfDownloadException(PaperPdfDownloadFailure.FileTooSmall, "PDF download is too small to be valid.");
        }
        if (response.Data.Length > maximumBytes)
        {
            throw new PaperPdfDownloadException(PaperPdfDownloadFailure.FileTooLarge, "PDF download exceeds the configured size limit.");
        }
        if (!response.Data.AsSpan().StartsWith(PdfSignature))
        {
            throw new PaperPdfDownloadException(PaperPdfDownloadFailure.InvalidPdfSignature, "PDF download does not have a PDF file signature.");
        }

        return new DownloadedPaperPdf(
            response.Data,
            Convert.ToHexString(SHA256.HashData(response.Data)).ToLowerInvariant(),
            response.MimeType ?? "application/pdf");
    }

    private static Uri ResolveVerifiedUrl(PaperCandidate paper)
    {
        if (paper.OpenAccessEvidence?.Status != OpenAccessStatus.Verified)
        {
            throw new PaperPdfDownloadException(PaperPdfDownloadFailure.UnverifiedOpenAccess, "PDF download requires verified open-access evidence.");
        }

        Uri? url = paper.OpenAccessEvidence.Url ?? paper.OpenAccessPdfUrl;
        if (url is null)
        {
            throw new PaperPdfDownloadException(PaperPdfDownloadFailure.MissingPdfUrl, "No verified open-access PDF URL is available.");
        }
        if (!string.Equals(url.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase))
        {
            throw new PaperPdfDownloadException(PaperPdfDownloadFailure.InsecureUrl, "PDF download requires HTTPS.");
        }

        return url;
    }
}
