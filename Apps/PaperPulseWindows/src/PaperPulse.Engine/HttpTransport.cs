using System.Globalization;
using System.Net;

namespace PaperPulse.Engine;

public sealed class HttpResponse
{
    public HttpResponse(
        byte[] data,
        int statusCode,
        string? mimeType,
        Uri finalUri,
        IReadOnlyDictionary<string, string>? headers = null)
    {
        Data = data;
        StatusCode = statusCode;
        MimeType = mimeType;
        FinalUri = finalUri;
        Headers = (headers ?? new Dictionary<string, string>())
            .ToDictionary(
                pair => pair.Key.Trim().ToLowerInvariant(),
                pair => pair.Value,
                StringComparer.OrdinalIgnoreCase);
    }

    public byte[] Data { get; }
    public int StatusCode { get; }
    public string? MimeType { get; }
    public Uri FinalUri { get; }
    public IReadOnlyDictionary<string, string> Headers { get; }

    public HttpResponse RequireSuccess()
    {
        if (StatusCode is < 200 or >= 300)
        {
            throw new HttpStatusException(StatusCode);
        }

        return this;
    }
}

public sealed class HttpStatusException(int statusCode) : Exception($"HTTP {statusCode}")
{
    public int StatusCode { get; } = statusCode;
}

public interface IHttpTransport
{
    Task<HttpResponse> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken = default);
}

public sealed class HttpClientTransport(HttpClient client) : IHttpTransport
{
    public async Task<HttpResponse> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken = default)
    {
        using HttpResponseMessage response = await client.SendAsync(request, cancellationToken).ConfigureAwait(false);
        byte[] data = await response.Content.ReadAsByteArrayAsync(cancellationToken).ConfigureAwait(false);
        IReadOnlyDictionary<string, string> headers = response.Headers
            .Concat(response.Content.Headers)
            .ToDictionary(header => header.Key, header => string.Join(",", header.Value), StringComparer.OrdinalIgnoreCase);
        return new HttpResponse(
            data,
            (int)response.StatusCode,
            response.Content.Headers.ContentType?.MediaType,
            response.RequestMessage?.RequestUri ?? request.RequestUri ?? new Uri("about:blank"),
            headers);
    }
}

public sealed class HttpRetryPolicy
{
    public HttpRetryPolicy(
        int maximumRetryCount = 2,
        TimeSpan? baseDelay = null,
        TimeSpan? maximumDelay = null)
    {
        MaximumRetryCount = Math.Max(0, maximumRetryCount);
        BaseDelay = baseDelay.GetValueOrDefault(TimeSpan.FromSeconds(1));
        MaximumDelay = maximumDelay.GetValueOrDefault(TimeSpan.FromSeconds(60));
    }

    public int MaximumRetryCount { get; }
    public TimeSpan BaseDelay { get; }
    public TimeSpan MaximumDelay { get; }

    public TimeSpan DelayForRetryAttempt(int retryAttempt)
    {
        if (BaseDelay <= TimeSpan.Zero || MaximumDelay <= TimeSpan.Zero)
        {
            return TimeSpan.Zero;
        }

        double factor = Math.Pow(2, Math.Max(0, retryAttempt - 1));
        double ticks = Math.Min(MaximumDelay.Ticks, BaseDelay.Ticks * factor);
        return TimeSpan.FromTicks((long)ticks);
    }
}

public sealed class RetryingHttpTransport(
    IHttpTransport inner,
    HttpRetryPolicy? retryPolicy = null,
    Func<TimeSpan, Task>? delay = null) : IHttpTransport
{
    private readonly HttpRetryPolicy retryPolicy = retryPolicy ?? new HttpRetryPolicy();
    private readonly Func<TimeSpan, Task> delay = delay ?? Task.Delay;

    public async Task<HttpResponse> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(request.RequestUri);
        int retryAttempt = 0;

        while (true)
        {
            cancellationToken.ThrowIfCancellationRequested();
            HttpResponse response = await inner.SendAsync(Clone(request), cancellationToken).ConfigureAwait(false);
            if (!ShouldRetry(response.StatusCode) || retryAttempt >= retryPolicy.MaximumRetryCount)
            {
                return response;
            }

            retryAttempt++;
            cancellationToken.ThrowIfCancellationRequested();
            await delay(retryPolicy.DelayForRetryAttempt(retryAttempt)).ConfigureAwait(false);
        }
    }

    private static bool ShouldRetry(int statusCode) => statusCode == (int)HttpStatusCode.TooManyRequests || statusCode is >= 500 and < 600;

    private static HttpRequestMessage Clone(HttpRequestMessage request)
    {
        HttpRequestMessage clone = new(request.Method, request.RequestUri);
        foreach (KeyValuePair<string, IEnumerable<string>> header in request.Headers)
        {
            clone.Headers.TryAddWithoutValidation(header.Key, header.Value);
        }
        return clone;
    }
}
