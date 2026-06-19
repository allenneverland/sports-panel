using System.Drawing;
using System.Windows.Forms;

namespace SportsPanel.UninstallGuard;

internal static class Program
{
    [STAThread]
    private static int Main(string[] args)
    {
        if (args.Length != 1)
        {
            return 2;
        }

        Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(defaultValue: false);

        using var form = new PasswordForm(args[0]);
        return form.ShowDialog() == DialogResult.OK ? 0 : 1;
    }
}

internal sealed class PasswordForm : Form
{
    private readonly string _expectedPassword;
    private readonly TextBox _passwordTextBox;

    public PasswordForm(string expectedPassword)
    {
        _expectedPassword = expectedPassword;

        Text = "Sports Panel Uninstall";
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        MinimizeBox = false;
        ShowIcon = false;
        ShowInTaskbar = false;
        StartPosition = FormStartPosition.CenterScreen;
        ClientSize = new Size(360, 132);

        var label = new Label
        {
            AutoSize = true,
            Location = new Point(12, 16),
            Text = "Enter the uninstall password:"
        };

        _passwordTextBox = new TextBox
        {
            Location = new Point(12, 44),
            Size = new Size(336, 23),
            UseSystemPasswordChar = true
        };

        var okButton = new Button
        {
            Location = new Point(184, 92),
            Size = new Size(80, 27),
            Text = "OK"
        };
        okButton.Click += OnOkClicked;

        var cancelButton = new Button
        {
            DialogResult = DialogResult.Cancel,
            Location = new Point(268, 92),
            Size = new Size(80, 27),
            Text = "Cancel"
        };

        AcceptButton = okButton;
        CancelButton = cancelButton;

        Controls.Add(label);
        Controls.Add(_passwordTextBox);
        Controls.Add(okButton);
        Controls.Add(cancelButton);
    }

    protected override void OnShown(EventArgs e)
    {
        base.OnShown(e);
        _passwordTextBox.Focus();
    }

    private void OnOkClicked(object? sender, EventArgs e)
    {
        if (_passwordTextBox.Text == _expectedPassword)
        {
            DialogResult = DialogResult.OK;
            Close();
            return;
        }

        MessageBox.Show(
            this,
            "Incorrect uninstall password.",
            "Sports Panel Uninstall",
            MessageBoxButtons.OK,
            MessageBoxIcon.Error);
        _passwordTextBox.SelectAll();
        _passwordTextBox.Focus();
    }
}

