using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace SafeMacCleaner.Windows;

public enum PageKind
{
    Smart,
    Large,
    Apps,
    Leftovers,
    Related
}

public sealed class CleanupItem : INotifyPropertyChanged
{
    private bool _checked;

    public bool Checked
    {
        get => _checked;
        set
        {
            if (_checked == value) return;
            _checked = value;
            OnPropertyChanged();
        }
    }

    public string Name { get; init; } = "";
    public long Size { get; init; }
    public string Category { get; init; } = "";
    public string Recommendation { get; init; } = "";
    public string Path { get; init; } = "";
    public bool CanDelete { get; init; } = true;
    public bool IsDirectory { get; init; }

    public string SizeText => Format.Bytes(Size);

    public event PropertyChangedEventHandler? PropertyChanged;

    private void OnPropertyChanged([CallerMemberName] string? name = null)
        => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
}

public sealed class AppItem
{
    public string Name { get; init; } = "";
    public string Version { get; init; } = "—";
    public string Publisher { get; init; } = "—";
    public string InstallLocation { get; init; } = "";
    public string UninstallString { get; init; } = "";
    public long Size { get; init; }
    public string SizeText => Size > 0 ? Format.Bytes(Size) : "—";
}

public sealed record ScanProgressInfo(
    string Phase,
    string CurrentPath,
    int Processed,
    int Found,
    int PhaseIndex,
    int PhaseCount)
{
    public double Fraction =>
        PhaseCount <= 0
            ? 0
            : Math.Clamp((double)Math.Max(0, PhaseIndex - 1) / PhaseCount, 0, 1);

    public string PercentText => $"{Fraction * 100:0}%";
}

public static class Format
{
    public static string Bytes(long bytes)
    {
        if (bytes < 1024) return $"{bytes} B";
        double value = bytes;
        string[] units = ["KB", "MB", "GB", "TB"];
        int index = -1;

        do
        {
            value /= 1024;
            index++;
        }
        while (value >= 1024 && index < units.Length - 1);

        return value >= 100
            ? $"{value:0} {units[index]}"
            : value >= 10
                ? $"{value:0.0} {units[index]}"
                : $"{value:0.00} {units[index]}";
    }
}
