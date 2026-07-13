using System.Globalization;
using Microsoft.Data.Sqlite;
using PaperPulse.Contracts;

namespace PaperPulse.Storage;

public sealed record class StoredPaper(PaperCandidate Candidate, string? PdfRelativePath, string? PdfSha256, DateTimeOffset CreatedAt, bool IsFavorite);

public sealed class SqlitePaperPulseRepository
{
    private readonly PaperPulsePaths paths;

    public SqlitePaperPulseRepository(PaperPulsePaths paths)
    {
        this.paths = paths;
    }

    public void Initialize()
    {
        paths.EnsureCreated();
        using SqliteConnection connection = Open();
        connection.Open();
        Execute(connection, "CREATE TABLE IF NOT EXISTS schema_migrations (version INTEGER PRIMARY KEY, applied_at TEXT NOT NULL);");
        if (ScalarLong(connection, "SELECT COUNT(*) FROM schema_migrations WHERE version = 1;") == 0)
        {
            Execute(connection, """
                CREATE TABLE feeds (id TEXT PRIMARY KEY, configuration_json TEXT NOT NULL, created_at TEXT NOT NULL);
                CREATE TABLE papers (id TEXT PRIMARY KEY, candidate_json TEXT NOT NULL, pdf_relative_path TEXT, pdf_sha256 TEXT, created_at TEXT NOT NULL, is_favorite INTEGER NOT NULL DEFAULT 0);
                CREATE TABLE feed_papers (feed_id TEXT NOT NULL, paper_id TEXT NOT NULL, pushed_at TEXT NOT NULL, PRIMARY KEY (feed_id, paper_id));
                CREATE TABLE summaries (id TEXT PRIMARY KEY, paper_id TEXT NOT NULL, metadata_json TEXT NOT NULL, markdown_relative_path TEXT);
                CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);
                """);
            using SqliteCommand migration = connection.CreateCommand();
            migration.CommandText = "INSERT INTO schema_migrations (version, applied_at) VALUES (1, $at);";
            migration.Parameters.AddWithValue("$at", DateTimeOffset.UtcNow.ToString("O", CultureInfo.InvariantCulture));
            migration.ExecuteNonQuery();
        }
    }

    public void SaveFeed(FeedConfig feed)
    {
        Initialize();
        using SqliteConnection connection = Open(); connection.Open();
        using SqliteCommand command = connection.CreateCommand();
        command.CommandText = "INSERT INTO feeds (id, configuration_json, created_at) VALUES ($id, $json, $at) ON CONFLICT(id) DO UPDATE SET configuration_json = excluded.configuration_json;";
        command.Parameters.AddWithValue("$id", feed.Id.ToString("D"));
        command.Parameters.AddWithValue("$json", System.Text.Json.JsonSerializer.Serialize(feed, PaperPulseJson.Options));
        command.Parameters.AddWithValue("$at", DateTimeOffset.UtcNow.ToString("O", CultureInfo.InvariantCulture));
        command.ExecuteNonQuery();
    }

    public IReadOnlyList<FeedConfig> LoadFeeds()
    {
        Initialize();
        using SqliteConnection connection = Open(); connection.Open();
        using SqliteCommand command = connection.CreateCommand(); command.CommandText = "SELECT configuration_json FROM feeds ORDER BY created_at;";
        using SqliteDataReader reader = command.ExecuteReader();
        List<FeedConfig> feeds = [];
        while (reader.Read()) feeds.Add(System.Text.Json.JsonSerializer.Deserialize<FeedConfig>(reader.GetString(0), PaperPulseJson.Options)!);
        return feeds;
    }

    public void SavePaper(StoredPaper paper, Guid? feedId = null)
    {
        Initialize();
        using SqliteConnection connection = Open(); connection.Open(); using SqliteTransaction transaction = connection.BeginTransaction();
        using (SqliteCommand command = connection.CreateCommand())
        {
            command.Transaction = transaction;
            command.CommandText = "INSERT INTO papers (id, candidate_json, pdf_relative_path, pdf_sha256, created_at, is_favorite) VALUES ($id,$candidate,$path,$sha,$created,$favorite) ON CONFLICT(id) DO UPDATE SET candidate_json=excluded.candidate_json,pdf_relative_path=excluded.pdf_relative_path,pdf_sha256=excluded.pdf_sha256,created_at=excluded.created_at,is_favorite=excluded.is_favorite;";
            command.Parameters.AddWithValue("$id", paper.Candidate.StableId);
            command.Parameters.AddWithValue("$candidate", System.Text.Json.JsonSerializer.Serialize(paper.Candidate, PaperPulseJson.Options));
            command.Parameters.AddWithValue("$path", (object?)paper.PdfRelativePath ?? DBNull.Value);
            command.Parameters.AddWithValue("$sha", (object?)paper.PdfSha256 ?? DBNull.Value);
            command.Parameters.AddWithValue("$created", paper.CreatedAt.ToString("O", CultureInfo.InvariantCulture));
            command.Parameters.AddWithValue("$favorite", paper.IsFavorite ? 1 : 0);
            command.ExecuteNonQuery();
        }
        if (feedId is Guid id) LinkPaper(connection, transaction, paper.Candidate.StableId, id);
        transaction.Commit();
    }

    public void SetFavorite(string paperId, bool isFavorite)
    {
        Initialize(); using SqliteConnection connection = Open(); connection.Open();
        using SqliteCommand command = connection.CreateCommand(); command.CommandText = "UPDATE papers SET is_favorite=$favorite WHERE id=$id;";
        command.Parameters.AddWithValue("$id", paperId); command.Parameters.AddWithValue("$favorite", isFavorite ? 1 : 0); command.ExecuteNonQuery();
    }

    public IReadOnlyList<StoredPaper> LoadPapers()
    {
        Initialize(); using SqliteConnection connection = Open(); connection.Open(); using SqliteCommand command = connection.CreateCommand();
        command.CommandText = "SELECT candidate_json,pdf_relative_path,pdf_sha256,created_at,is_favorite FROM papers ORDER BY created_at DESC;";
        using SqliteDataReader reader = command.ExecuteReader(); List<StoredPaper> papers = [];
        while (reader.Read()) papers.Add(new StoredPaper(System.Text.Json.JsonSerializer.Deserialize<PaperCandidate>(reader.GetString(0), PaperPulseJson.Options)!, reader.IsDBNull(1) ? null : reader.GetString(1), reader.IsDBNull(2) ? null : reader.GetString(2), DateTimeOffset.Parse(reader.GetString(3), CultureInfo.InvariantCulture), reader.GetInt64(4) != 0));
        return papers;
    }

    public IReadOnlySet<string> PaperIdsForFeed(Guid feedId) => IdSet("SELECT paper_id FROM feed_papers WHERE feed_id=$id;", feedId.ToString("D"));

    public IReadOnlySet<string> UnclassifiedPaperIds() => IdSet("SELECT p.id FROM papers p WHERE NOT EXISTS (SELECT 1 FROM feed_papers fp INNER JOIN feeds f ON f.id=fp.feed_id WHERE fp.paper_id=p.id);");

    public void DeleteFeed(Guid feedId)
    {
        Initialize(); using SqliteConnection connection = Open(); connection.Open(); using SqliteTransaction transaction = connection.BeginTransaction();
        Execute(connection, "DELETE FROM feed_papers WHERE feed_id=$id;", "$id", feedId.ToString("D"), transaction: transaction);
        Execute(connection, "DELETE FROM feeds WHERE id=$id;", "$id", feedId.ToString("D"), transaction: transaction); transaction.Commit();
    }

    public int ClearUnclassifiedPapers()
    {
        Initialize(); using SqliteConnection connection = Open(); connection.Open();
        using SqliteCommand command = connection.CreateCommand(); command.CommandText = "DELETE FROM papers WHERE NOT EXISTS (SELECT 1 FROM feed_papers fp INNER JOIN feeds f ON f.id=fp.feed_id WHERE fp.paper_id=papers.id);";
        return command.ExecuteNonQuery();
    }

    public void SetSetting(string key, string value) { Initialize(); using SqliteConnection connection = Open(); connection.Open(); Execute(connection, "INSERT INTO settings (key,value) VALUES ($key,$value) ON CONFLICT(key) DO UPDATE SET value=excluded.value;", "$key", key, extraName: "$value", extraValue: value); }
    public string? GetSetting(string key) { Initialize(); using SqliteConnection connection = Open(); connection.Open(); using SqliteCommand command = connection.CreateCommand(); command.CommandText = "SELECT value FROM settings WHERE key=$key;"; command.Parameters.AddWithValue("$key", key); return command.ExecuteScalar() as string; }

    private SqliteConnection Open() => new(new SqliteConnectionStringBuilder { DataSource = paths.DatabasePath }.ToString());
    private static long ScalarLong(SqliteConnection c, string sql) { using SqliteCommand command = c.CreateCommand(); command.CommandText = sql; return (long)(command.ExecuteScalar() ?? 0L); }
    private static void LinkPaper(SqliteConnection c, SqliteTransaction t, string paperId, Guid feedId)
    {
        using SqliteCommand command = c.CreateCommand();
        command.Transaction = t;
        command.CommandText = "INSERT OR IGNORE INTO feed_papers (feed_id,paper_id,pushed_at) VALUES ($feed,$paper,$at);";
        command.Parameters.AddWithValue("$feed", feedId.ToString("D"));
        command.Parameters.AddWithValue("$paper", paperId);
        command.Parameters.AddWithValue("$at", DateTimeOffset.UtcNow.ToString("O", CultureInfo.InvariantCulture));
        command.ExecuteNonQuery();
    }
    private IReadOnlySet<string> IdSet(string sql, string? id = null) { Initialize(); using SqliteConnection c = Open(); c.Open(); using SqliteCommand command = c.CreateCommand(); command.CommandText = sql; if (id is not null) command.Parameters.AddWithValue("$id", id); using SqliteDataReader reader = command.ExecuteReader(); HashSet<string> ids = []; while (reader.Read()) ids.Add(reader.GetString(0)); return ids; }
    private static void Execute(SqliteConnection c, string sql, string? name = null, object? value = null, string? extraName = null, object? extraValue = null, SqliteTransaction? transaction = null) { using SqliteCommand command = c.CreateCommand(); command.Transaction = transaction; command.CommandText = sql; if (name is not null) command.Parameters.AddWithValue(name, value ?? DBNull.Value); if (extraName is not null) command.Parameters.AddWithValue(extraName, extraValue ?? DBNull.Value); command.ExecuteNonQuery(); }
}
