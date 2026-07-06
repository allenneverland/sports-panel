using Xunit;

namespace SportsPanel.Host.Tests;

public sealed class NavigationPolicyTests
{
    private readonly NavigationPolicy _policy = new(new Uri("https://test123.com/panel?league=nba"));

    [Theory]
    [InlineData("https://test123.com/page2")]
    [InlineData("https://test123.com:443/page2")]
    [InlineData("HTTPS://TEST123.COM/page2")]
    public void IsAllowed_ReturnsTrue_ForSameOrigin(string value)
    {
        Assert.True(_policy.IsAllowed(value));
    }

    [Theory]
    [InlineData("http://test123.com")]
    [InlineData("https://sub.test123.com")]
    [InlineData("https://test123.com.evil.com")]
    [InlineData("https://eviltest123.com")]
    [InlineData("https://google.com")]
    [InlineData("file:///C:/panel.html")]
    [InlineData("about:blank")]
    [InlineData("not a url")]
    public void IsAllowed_ReturnsFalse_ForExternalOrInvalidUrls(string value)
    {
        Assert.False(_policy.IsAllowed(value));
    }

    [Fact]
    public void IsAllowed_ReturnsFalse_ForDifferentPort()
    {
        var policy = new NavigationPolicy(new Uri("https://test123.com:8443/panel"));

        Assert.True(policy.IsAllowed("https://test123.com:8443/page2"));
        Assert.False(policy.IsAllowed("https://test123.com/page2"));
    }
}
