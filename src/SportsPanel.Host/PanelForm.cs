using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;
using Microsoft.Win32;
using System.Drawing;
using System.Net;
using System.Text;
using System.Windows.Forms;

namespace SportsPanel.Host;

internal sealed class PanelForm : Form
{
    private const int AppBarCallback = NativeMethods.WM_APP + 1;
    private const string HideScrollbarsScript = """
        (() => {
            const css = `
                html, body {
                    scrollbar-width: none !important;
                    -ms-overflow-style: none !important;
                }

                *::-webkit-scrollbar {
                    width: 0 !important;
                    height: 0 !important;
                    display: none !important;
                }
            `;

            const install = () => {
                if (document.querySelector('style[data-sports-panel-scrollbars="hidden"]')) {
                    return;
                }

                const style = document.createElement('style');
                style.setAttribute('data-sports-panel-scrollbars', 'hidden');
                style.textContent = css;
                (document.head || document.documentElement).appendChild(style);
            };

            if (document.documentElement) {
                install();
            } else {
                document.addEventListener('DOMContentLoaded', install, { once: true });
            }
        })();
        """;

    private readonly PanelOptions _options;
    private readonly WebView2 _webView;
    private readonly Label _statusLabel;
    private AppBar? _appBar;
    private bool _systemClosing;

    public PanelForm(PanelOptions options)
    {
        _options = options;

        Text = "Sports Panel";
        BackColor = Color.Black;
        FormBorderStyle = FormBorderStyle.None;
        MaximizeBox = false;
        MinimizeBox = false;
        ShowIcon = false;
        ShowInTaskbar = false;
        SizeGripStyle = SizeGripStyle.Hide;
        StartPosition = FormStartPosition.Manual;

        _webView = new WebView2
        {
            Dock = DockStyle.Fill,
            DefaultBackgroundColor = Color.Black
        };

        _statusLabel = new Label
        {
            Dock = DockStyle.Fill,
            ForeColor = Color.White,
            BackColor = Color.FromArgb(18, 18, 18),
            TextAlign = ContentAlignment.MiddleCenter,
            Padding = new Padding(24),
            Visible = false
        };

        Controls.Add(_webView);
        Controls.Add(_statusLabel);
    }

    protected override CreateParams CreateParams
    {
        get
        {
            var createParams = base.CreateParams;
            createParams.ExStyle |= NativeMethods.WS_EX_TOOLWINDOW;
            createParams.ExStyle &= ~NativeMethods.WS_EX_APPWINDOW;
            return createParams;
        }
    }

    protected override void OnLoad(EventArgs e)
    {
        base.OnLoad(e);

        _appBar = new AppBar(Handle);
        if (!_appBar.Register((uint)AppBarCallback))
        {
            ShowStatus("Could not register the right-side Windows AppBar.");
            return;
        }

        PositionAppBar();
        SystemEvents.DisplaySettingsChanged += OnDisplaySettingsChanged;
        SystemEvents.UserPreferenceChanged += OnUserPreferenceChanged;

        _ = InitializeWebViewAsync();
    }

    protected override void OnFormClosing(FormClosingEventArgs e)
    {
        if (!_systemClosing && (e.CloseReason is CloseReason.UserClosing or CloseReason.ApplicationExitCall))
        {
            e.Cancel = true;
            return;
        }

        base.OnFormClosing(e);
    }

    protected override void OnFormClosed(FormClosedEventArgs e)
    {
        SystemEvents.DisplaySettingsChanged -= OnDisplaySettingsChanged;
        SystemEvents.UserPreferenceChanged -= OnUserPreferenceChanged;
        _appBar?.Dispose();
        _webView.Dispose();

        base.OnFormClosed(e);
    }

    protected override bool ProcessCmdKey(ref Message msg, Keys keyData)
    {
        if (keyData == (Keys.Alt | Keys.F4))
        {
            return true;
        }

        return base.ProcessCmdKey(ref msg, keyData);
    }

    protected override void WndProc(ref Message m)
    {
        switch (m.Msg)
        {
            case NativeMethods.WM_QUERYENDSESSION:
                _systemClosing = true;
                break;

            case NativeMethods.WM_ENDSESSION:
                _systemClosing = m.WParam != IntPtr.Zero;
                break;

            case NativeMethods.WM_CLOSE:
                if (!_systemClosing)
                {
                    return;
                }

                break;

            case NativeMethods.WM_ACTIVATE:
                _appBar?.Activate(m.WParam != IntPtr.Zero);
                break;

            case NativeMethods.WM_WINDOWPOSCHANGED:
                base.WndProc(ref m);
                _appBar?.NotifyWindowPositionChanged();
                return;
        }

        if (m.Msg == AppBarCallback)
        {
            HandleAppBarCallback(m.WParam.ToInt32(), m.LParam != IntPtr.Zero);
            return;
        }

        base.WndProc(ref m);
    }

    private async Task InitializeWebViewAsync()
    {
        try
        {
            var userDataFolder = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "SportsPanel",
                "WebView2");
            Directory.CreateDirectory(userDataFolder);

            var environment = await CoreWebView2Environment.CreateAsync(
                browserExecutableFolder: null,
                userDataFolder: userDataFolder);

            await _webView.EnsureCoreWebView2Async(environment);
            _webView.CoreWebView2.Settings.AreDefaultContextMenusEnabled = false;
            _webView.CoreWebView2.Settings.AreDevToolsEnabled = false;
            await _webView.CoreWebView2.AddScriptToExecuteOnDocumentCreatedAsync(HideScrollbarsScript);

            if (_options.Url is not null)
            {
                _webView.CoreWebView2.Navigate(_options.Url.AbsoluteUri);
                return;
            }

            _webView.CoreWebView2.NavigateToString(BuildConfigurationErrorHtml());
        }
        catch (Exception ex)
        {
            ShowStatus($"WebView2 could not be initialized.{Environment.NewLine}{ex.Message}");
        }
    }

    private void HandleAppBarCallback(int notification, bool isFullScreenOpening)
    {
        switch (notification)
        {
            case NativeMethods.ABN_POSCHANGED:
                PositionAppBar();
                break;

            case NativeMethods.ABN_FULLSCREENAPP:
                if (isFullScreenOpening)
                {
                    _appBar?.SendBehindFullScreenApp();
                }
                else
                {
                    PositionAppBar();
                }

                break;
        }
    }

    private void PositionAppBar()
    {
        if (_appBar is null || IsDisposed)
        {
            return;
        }

        var screen = ResolveScreen();
        _appBar.SetRightEdge(screen.Bounds, _options.WidthPx);
    }

    private Screen ResolveScreen()
    {
        if (!string.Equals(_options.Monitor, "primary", StringComparison.OrdinalIgnoreCase))
        {
            foreach (var screen in Screen.AllScreens)
            {
                if (string.Equals(screen.DeviceName, _options.Monitor, StringComparison.OrdinalIgnoreCase))
                {
                    return screen;
                }
            }
        }

        return Screen.PrimaryScreen ?? Screen.AllScreens[0];
    }

    private void OnDisplaySettingsChanged(object? sender, EventArgs e) =>
        BeginInvokeIfAvailable(PositionAppBar);

    private void OnUserPreferenceChanged(object? sender, UserPreferenceChangedEventArgs e) =>
        BeginInvokeIfAvailable(PositionAppBar);

    private void BeginInvokeIfAvailable(Action action)
    {
        if (IsDisposed || !IsHandleCreated)
        {
            return;
        }

        BeginInvoke(action);
    }

    private void ShowStatus(string message)
    {
        _webView.Visible = false;
        _statusLabel.Text = message;
        _statusLabel.Visible = true;
        _statusLabel.BringToFront();
    }

    private string BuildConfigurationErrorHtml()
    {
        var message = WebUtility.HtmlEncode(_options.ConfigurationError ?? "Configuration is invalid.");
        var path = WebUtility.HtmlEncode(PanelOptions.DefaultPath);
        var builder = new StringBuilder();
        builder.AppendLine("<!doctype html>");
        builder.AppendLine("<meta charset=\"utf-8\">");
        builder.AppendLine("<style>");
        builder.AppendLine("html,body{height:100%;margin:0;background:#121212;color:#fff;font:14px Segoe UI,Arial,sans-serif;}");
        builder.AppendLine("main{box-sizing:border-box;display:flex;height:100%;align-items:center;justify-content:center;padding:24px;text-align:center;}");
        builder.AppendLine("p{margin:8px 0;line-height:1.45;}");
        builder.AppendLine("code{word-break:break-all;color:#9cdcfe;}");
        builder.AppendLine("</style>");
        builder.AppendLine("<main><div>");
        builder.AppendLine("<p>Sports Panel is not configured.</p>");
        builder.AppendLine($"<p>{message}</p>");
        builder.AppendLine($"<p><code>{path}</code></p>");
        builder.AppendLine("</div></main>");
        return builder.ToString();
    }
}
