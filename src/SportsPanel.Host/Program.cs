using System.Threading;
using System.Windows.Forms;

namespace SportsPanel.Host;

internal static class Program
{
    private const string MutexName = @"Local\SportsPanel.Host";

    [STAThread]
    private static void Main()
    {
        using var mutex = new Mutex(initiallyOwned: true, MutexName, out var createdNew);
        if (!createdNew)
        {
            return;
        }

        Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(defaultValue: false);

        Application.Run(new PanelForm(PanelOptions.Load()));
    }
}
