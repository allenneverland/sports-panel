using System.Text.Json;

namespace SportsPanel.Host;

internal sealed class PanelOptions
{
    private const int DefaultWidthPx = 420;
    private const string DefaultMonitor = "primary";

    private PanelOptions(Uri? url, int widthPx, string monitor, string? configurationError)
    {
        Url = url;
        WidthPx = widthPx;
        Monitor = monitor;
        ConfigurationError = configurationError;
    }

    public Uri? Url { get; }

    public int WidthPx { get; }

    public string Monitor { get; }

    public string? ConfigurationError { get; }

    public static string DefaultPath =>
        Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
            "SportsPanel",
            "panel.json");

    public static PanelOptions Load()
    {
        if (!File.Exists(DefaultPath))
        {
            return Error($"Configuration file not found: {DefaultPath}");
        }

        try
        {
            var json = File.ReadAllText(DefaultPath);
            var file = JsonSerializer.Deserialize<PanelOptionsFile>(
                json,
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

            if (file is null)
            {
                return Error($"Configuration file is empty: {DefaultPath}");
            }

            if (!TryCreateWebUri(file.Url, out var url))
            {
                return Error("Configuration value 'url' must be an absolute http or https URL.");
            }

            var widthPx = file.WidthPx.GetValueOrDefault(DefaultWidthPx);
            if (widthPx <= 0)
            {
                widthPx = DefaultWidthPx;
            }

            var monitor = string.IsNullOrWhiteSpace(file.Monitor)
                ? DefaultMonitor
                : file.Monitor.Trim();

            return new PanelOptions(url, widthPx, monitor, configurationError: null);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or JsonException)
        {
            return Error($"Configuration file could not be read: {ex.Message}");
        }
    }

    private static PanelOptions Error(string message) =>
        new(url: null, DefaultWidthPx, DefaultMonitor, message);

    private static bool TryCreateWebUri(string? value, out Uri? uri)
    {
        uri = null;
        if (!Uri.TryCreate(value, UriKind.Absolute, out var candidate))
        {
            return false;
        }

        if (candidate.Scheme != Uri.UriSchemeHttp && candidate.Scheme != Uri.UriSchemeHttps)
        {
            return false;
        }

        uri = candidate;
        return true;
    }

    private sealed class PanelOptionsFile
    {
        public string? Url { get; set; }

        public int? WidthPx { get; set; }

        public string? Monitor { get; set; }
    }
}

