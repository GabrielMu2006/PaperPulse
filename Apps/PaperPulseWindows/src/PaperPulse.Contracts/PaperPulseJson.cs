using System.Globalization;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace PaperPulse.Contracts;

public static class PaperPulseJson
{
    private static readonly DateTimeOffset SwiftReferenceDate = new(2001, 1, 1, 0, 0, 0, TimeSpan.Zero);

    public static JsonSerializerOptions Options { get; } = CreateOptions();

    public static string SourceName(PaperSourceKind source) => source switch
    {
        PaperSourceKind.Arxiv => "arxiv",
        PaperSourceKind.SemanticScholar => "semanticScholar",
        PaperSourceKind.OpenAlex => "openAlex",
        PaperSourceKind.Crossref => "crossref",
        PaperSourceKind.Unpaywall => "unpaywall",
        PaperSourceKind.Web => "web",
        _ => throw new ArgumentOutOfRangeException(nameof(source), source, null)
    };

    private static JsonSerializerOptions CreateOptions()
    {
        JsonSerializerOptions options = new()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
        };
        options.Converters.Add(new JsonStringEnumConverter(JsonNamingPolicy.CamelCase));
        options.Converters.Add(new SwiftReferenceDateTimeOffsetConverter(SwiftReferenceDate));
        return options;
    }

    private sealed class SwiftReferenceDateTimeOffsetConverter(DateTimeOffset referenceDate) : JsonConverter<DateTimeOffset>
    {
        public override DateTimeOffset Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options)
        {
            if (reader.TokenType == JsonTokenType.Number && reader.TryGetDouble(out double seconds))
            {
                return referenceDate.AddSeconds(seconds);
            }

            if (reader.TokenType == JsonTokenType.String && reader.TryGetDateTimeOffset(out DateTimeOffset value))
            {
                return value;
            }

            throw new JsonException("Expected a Swift reference-date number or ISO 8601 timestamp.");
        }

        public override void Write(Utf8JsonWriter writer, DateTimeOffset value, JsonSerializerOptions options)
        {
            writer.WriteNumberValue(value.ToUniversalTime().Subtract(referenceDate).TotalSeconds);
        }
    }
}
