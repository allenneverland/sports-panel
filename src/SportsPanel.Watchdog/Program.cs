using System.Diagnostics;

namespace SportsPanel.Watchdog;

internal static class Program
{
    private const string MutexName = @"Local\SportsPanel.Watchdog";
    private const string HostProcessName = "SportsPanel.Host";
    private static readonly TimeSpan PollInterval = TimeSpan.FromSeconds(3);

    private static int Main()
    {
        using var mutex = new Mutex(initiallyOwned: true, MutexName, out var createdNew);
        if (!createdNew)
        {
            return 0;
        }

        var appDirectory = AppContext.BaseDirectory;
        var hostPath = Path.Combine(appDirectory, $"{HostProcessName}.exe");
        if (!File.Exists(hostPath))
        {
            Log($"Host executable not found: {hostPath}");
            return 2;
        }

        var sessionId = Process.GetCurrentProcess().SessionId;
        while (true)
        {
            EnsureHostIsRunning(hostPath, appDirectory, sessionId);
            Thread.Sleep(PollInterval);
        }
    }

    private static void EnsureHostIsRunning(string hostPath, string appDirectory, int sessionId)
    {
        if (IsHostRunning(sessionId))
        {
            return;
        }

        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = hostPath,
                WorkingDirectory = appDirectory,
                UseShellExecute = false
            });
        }
        catch (Exception ex)
        {
            Log($"Could not start host: {ex.Message}");
        }
    }

    private static bool IsHostRunning(int sessionId)
    {
        foreach (var process in Process.GetProcessesByName(HostProcessName))
        {
            using (process)
            {
                try
                {
                    if (process.SessionId == sessionId && !process.HasExited)
                    {
                        return true;
                    }
                }
                catch (InvalidOperationException)
                {
                    // The process exited while it was being inspected.
                }
            }
        }

        return false;
    }

    private static void Log(string message)
    {
        try
        {
            var logDirectory = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "SportsPanel",
                "logs");
            Directory.CreateDirectory(logDirectory);
            File.AppendAllText(
                Path.Combine(logDirectory, "watchdog.log"),
                $"{DateTimeOffset.Now:u} {message}{Environment.NewLine}");
        }
        catch
        {
            // Logging must not stop the watchdog.
        }
    }
}

