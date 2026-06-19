using System.Drawing;
using System.Runtime.InteropServices;

namespace SportsPanel.Host;

internal sealed class AppBar : IDisposable
{
    private readonly nint _handle;
    private bool _registered;

    public AppBar(nint handle)
    {
        _handle = handle;
    }

    public bool Register(uint callbackMessage)
    {
        if (_registered)
        {
            return true;
        }

        var data = CreateData();
        data.uCallbackMessage = callbackMessage;
        _registered = NativeMethods.SHAppBarMessage(NativeMethods.ABM_NEW, ref data) != UIntPtr.Zero;
        return _registered;
    }

    public void SetRightEdge(Rectangle monitorBounds, int widthPx)
    {
        if (!_registered)
        {
            return;
        }

        var width = Math.Clamp(widthPx, 1, Math.Max(1, monitorBounds.Width));
        var data = CreateData();
        data.uEdge = NativeMethods.ABE_RIGHT;
        data.rc = new NativeMethods.Rect(
            monitorBounds.Right - width,
            monitorBounds.Top,
            monitorBounds.Right,
            monitorBounds.Bottom);

        NativeMethods.SHAppBarMessage(NativeMethods.ABM_QUERYPOS, ref data);
        data.rc.left = data.rc.right - width;
        NativeMethods.SHAppBarMessage(NativeMethods.ABM_SETPOS, ref data);

        NativeMethods.MoveWindow(
            _handle,
            data.rc.left,
            data.rc.top,
            data.rc.Width,
            data.rc.Height,
            repaint: true);
    }

    public void Activate(bool active)
    {
        if (!_registered)
        {
            return;
        }

        var data = CreateData();
        data.lParam = active ? (nint)1 : 0;
        NativeMethods.SHAppBarMessage(NativeMethods.ABM_ACTIVATE, ref data);
    }

    public void NotifyWindowPositionChanged()
    {
        if (!_registered)
        {
            return;
        }

        var data = CreateData();
        NativeMethods.SHAppBarMessage(NativeMethods.ABM_WINDOWPOSCHANGED, ref data);
    }

    public void SendBehindFullScreenApp()
    {
        NativeMethods.SetWindowPos(
            _handle,
            NativeMethods.HwndBottom,
            0,
            0,
            0,
            0,
            NativeMethods.SWP_NOMOVE | NativeMethods.SWP_NOSIZE | NativeMethods.SWP_NOACTIVATE);
    }

    public void Dispose()
    {
        if (!_registered)
        {
            return;
        }

        var data = CreateData();
        NativeMethods.SHAppBarMessage(NativeMethods.ABM_REMOVE, ref data);
        _registered = false;
    }

    private NativeMethods.AppBarData CreateData() =>
        new()
        {
            cbSize = (uint)Marshal.SizeOf<NativeMethods.AppBarData>(),
            hWnd = _handle
        };
}
