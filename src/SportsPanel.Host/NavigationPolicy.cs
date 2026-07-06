namespace SportsPanel.Host;

internal sealed class NavigationPolicy
{
    private readonly string _scheme;
    private readonly string _host;
    private readonly int _port;

    public NavigationPolicy(Uri configuredUrl)
    {
        if (!IsHttpOrHttps(configuredUrl))
        {
            throw new ArgumentException("Configured URL must be an absolute http or https URL.", nameof(configuredUrl));
        }

        _scheme = configuredUrl.Scheme;
        _host = configuredUrl.IdnHost;
        _port = configuredUrl.Port;
    }

    public bool IsAllowed(string? value)
    {
        if (!Uri.TryCreate(value, UriKind.Absolute, out var candidate))
        {
            return false;
        }

        return IsAllowed(candidate);
    }

    public bool IsAllowed(Uri candidate)
    {
        return IsHttpOrHttps(candidate) &&
            string.Equals(candidate.Scheme, _scheme, StringComparison.OrdinalIgnoreCase) &&
            string.Equals(candidate.IdnHost, _host, StringComparison.OrdinalIgnoreCase) &&
            candidate.Port == _port;
    }

    private static bool IsHttpOrHttps(Uri uri) =>
        uri.IsAbsoluteUri &&
        (uri.Scheme == Uri.UriSchemeHttp || uri.Scheme == Uri.UriSchemeHttps);
}
