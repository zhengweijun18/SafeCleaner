using Microsoft.Win32;
using System.Security;

namespace SafeMacCleaner.Windows;

public static class ScanEngine
{
    private static readonly string[] ProjectJunkNames =
    [
        "node_modules", "dist", "build", ".next", ".nuxt",
        ".turbo", "coverage", ".parcel-cache", ".vite"
    ];

    public static List<CleanupItem> ScanSmart(
        ScanSession session,
        Action<ScanProgressInfo> report)
    {
        var result = new List<CleanupItem>();
        var phases = new List<(string name, string path, Action action)>();

        string temp = Path.GetTempPath();
        phases.Add(("临时文件", temp, () =>
        {
            foreach (var entry in SafeEntries(temp))
            {
                session.Checkpoint();
                if (!IsOlderThan(entry, TimeSpan.FromDays(7))) continue;

                long size = SafeSize(entry, session);
                if (size <= 0) continue;

                result.Add(new CleanupItem
                {
                    Name = Path.GetFileName(entry.TrimEnd(Path.DirectorySeparatorChar)),
                    Size = size,
                    Category = "临时文件",
                    Recommendation = "推荐清理",
                    Path = entry,
                    CanDelete = true,
                    IsDirectory = Directory.Exists(entry),
                    Checked = true
                });
            }
        }));

        string npm = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "npm-cache");

        phases.Add(("开发缓存", npm, () =>
        {
            if (!Directory.Exists(npm)) return;
            long size = SafeSize(npm, session);
            if (size > 0)
            {
                result.Add(new CleanupItem
                {
                    Name = "npm-cache",
                    Size = size,
                    Category = "开发缓存",
                    Recommendation = "推荐清理",
                    Path = npm,
                    CanDelete = true,
                    IsDirectory = true,
                    Checked = true
                });
            }
        }));

        foreach (var root in DefaultProjectRoots())
        {
            phases.Add(("项目垃圾", root, () =>
            {
                ScanProjectJunk(root, result, session);
            }));
        }

        RunPhases(phases, session, result, report);
        return result;
    }

    public static List<CleanupItem> ScanLarge(
        ScanSession session,
        Action<ScanProgressInfo> report)
    {
        const long threshold = 500L * 1024 * 1024;
        var result = new List<CleanupItem>();
        var roots = DefaultLargeRoots().Where(Directory.Exists).Distinct().ToList();
        int processed = 0;

        for (int i = 0; i < roots.Count; i++)
        {
            string root = roots[i];
            foreach (var file in SafeFilesRecursive(root, session))
            {
                session.Checkpoint();
                processed++;

                long size = SafeFileSize(file);
                if (size >= threshold)
                {
                    result.Add(new CleanupItem
                    {
                        Name = Path.GetFileName(file),
                        Size = size,
                        Category = "大文件",
                        Recommendation = "人工判断",
                        Path = file,
                        CanDelete = true,
                        IsDirectory = false,
                        Checked = false
                    });
                }

                if (processed % 25 == 0)
                {
                    report(new ScanProgressInfo(
                        "大文件",
                        file,
                        processed,
                        result.Count,
                        i + 1,
                        Math.Max(roots.Count, 1)));
                }
            }
        }

        report(new ScanProgressInfo(
            "完成",
            "扫描完成",
            processed,
            result.Count,
            roots.Count + 1,
            Math.Max(roots.Count, 1)));

        return result
            .OrderByDescending(x => x.Size)
            .ToList();
    }

    public static List<AppItem> ScanApps(
        ScanSession session,
        Action<ScanProgressInfo> report)
    {
        var apps = new Dictionary<string, AppItem>(StringComparer.OrdinalIgnoreCase);
        var views = new[]
        {
            (RegistryHive.LocalMachine, RegistryView.Registry64),
            (RegistryHive.LocalMachine, RegistryView.Registry32),
            (RegistryHive.CurrentUser, RegistryView.Registry64),
            (RegistryHive.CurrentUser, RegistryView.Registry32)
        };

        int processed = 0;
        int phase = 0;

        foreach (var view in views)
        {
            phase++;
            session.Checkpoint();

            try
            {
                using var baseKey = RegistryKey.OpenBaseKey(view.Item1, view.Item2);
                using var uninstall = baseKey.OpenSubKey(
                    @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall");

                if (uninstall is null) continue;

                foreach (string subName in uninstall.GetSubKeyNames())
                {
                    session.Checkpoint();
                    processed++;

                    try
                    {
                        using var sub = uninstall.OpenSubKey(subName);
                        if (sub is null) continue;

                        string name = sub.GetValue("DisplayName") as string ?? "";
                        if (string.IsNullOrWhiteSpace(name)) continue;
                        if ((sub.GetValue("SystemComponent") as int? ?? 0) == 1) continue;

                        string version = sub.GetValue("DisplayVersion") as string ?? "—";
                        string publisher = sub.GetValue("Publisher") as string ?? "—";
                        string location = sub.GetValue("InstallLocation") as string ?? "";
                        string uninstallString = sub.GetValue("QuietUninstallString") as string
                            ?? sub.GetValue("UninstallString") as string
                            ?? "";

                        long estimated = 0;
                        object? est = sub.GetValue("EstimatedSize");
                        if (est is int estInt) estimated = (long)estInt * 1024;
                        if (est is long estLong) estimated = estLong * 1024;

                        apps[name] = new AppItem
                        {
                            Name = name,
                            Version = version,
                            Publisher = publisher,
                            InstallLocation = location,
                            UninstallString = uninstallString,
                            Size = estimated
                        };

                        if (processed % 20 == 0)
                        {
                            report(new ScanProgressInfo(
                                "应用",
                                name,
                                processed,
                                apps.Count,
                                phase,
                                views.Length));
                        }
                    }
                    catch
                    {
                    }
                }
            }
            catch
            {
            }
        }

        report(new ScanProgressInfo(
            "完成",
            "扫描完成",
            processed,
            apps.Count,
            views.Length + 1,
            views.Length));

        return apps.Values
            .OrderBy(x => x.Name, StringComparer.CurrentCultureIgnoreCase)
            .ToList();
    }

    public static List<CleanupItem> ScanLeftovers(
        IReadOnlyList<AppItem> installedApps,
        ScanSession session,
        Action<ScanProgressInfo> report)
    {
        var result = new List<CleanupItem>();
        var installed = installedApps
            .Select(x => NormalizeName(x.Name))
            .Where(x => x.Length >= 3)
            .ToHashSet(StringComparer.OrdinalIgnoreCase);

        var roots = new[]
        {
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData)
        }
        .Where(Directory.Exists)
        .Distinct()
        .ToList();

        int processed = 0;

        for (int i = 0; i < roots.Count; i++)
        {
            foreach (var dir in SafeDirectories(roots[i]))
            {
                session.Checkpoint();
                processed++;

                string folderName = Path.GetFileName(dir);
                string normalized = NormalizeName(folderName);

                if (normalized.Length < 4) continue;
                if (installed.Any(x => x.Contains(normalized) || normalized.Contains(x)))
                    continue;

                long size = SafeSize(dir, session);
                if (size < 5L * 1024 * 1024) continue;

                result.Add(new CleanupItem
                {
                    Name = folderName,
                    Size = size,
                    Category = "应用残留",
                    Recommendation = "人工判断",
                    Path = dir,
                    CanDelete = true,
                    IsDirectory = true,
                    Checked = false
                });

                if (processed % 10 == 0)
                {
                    report(new ScanProgressInfo(
                        "应用残留",
                        dir,
                        processed,
                        result.Count,
                        i + 1,
                        roots.Count));
                }
            }
        }

        report(new ScanProgressInfo(
            "完成",
            "扫描完成",
            processed,
            result.Count,
            roots.Count + 1,
            Math.Max(roots.Count, 1)));

        return result
            .OrderByDescending(x => x.Size)
            .ToList();
    }

    public static List<CleanupItem> ScanRelated(
        AppItem app,
        ScanSession session,
        Action<ScanProgressInfo> report)
    {
        var result = new List<CleanupItem>();
        string normalized = NormalizeName(app.Name);

        var roots = new[]
        {
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData)
        }
        .Where(Directory.Exists)
        .Distinct()
        .ToList();

        int processed = 0;

        for (int i = 0; i < roots.Count; i++)
        {
            foreach (var dir in SafeDirectories(roots[i]))
            {
                session.Checkpoint();
                processed++;

                string folderName = Path.GetFileName(dir);
                string folderNormalized = NormalizeName(folderName);

                if (folderNormalized.Length < 3) continue;
                if (!(folderNormalized == normalized ||
                      folderNormalized.Contains(normalized) ||
                      normalized.Contains(folderNormalized)))
                {
                    continue;
                }

                long size = SafeSize(dir, session);
                if (size <= 0) continue;

                bool exact = folderNormalized == normalized;

                result.Add(new CleanupItem
                {
                    Name = folderName,
                    Size = size,
                    Category = exact ? "精确关联" : "可能关联",
                    Recommendation = exact ? "推荐清理" : "人工判断",
                    Path = dir,
                    CanDelete = true,
                    IsDirectory = true,
                    Checked = exact
                });

                report(new ScanProgressInfo(
                    "关联文件",
                    dir,
                    processed,
                    result.Count,
                    i + 1,
                    roots.Count));
            }
        }

        report(new ScanProgressInfo(
            "完成",
            "扫描完成",
            processed,
            result.Count,
            roots.Count + 1,
            Math.Max(roots.Count, 1)));

        return result
            .OrderByDescending(x => x.Size)
            .ToList();
    }

    private static void RunPhases(
        List<(string name, string path, Action action)> phases,
        ScanSession session,
        List<CleanupItem> result,
        Action<ScanProgressInfo> report)
    {
        int processed = 0;

        for (int i = 0; i < phases.Count; i++)
        {
            session.Checkpoint();

            report(new ScanProgressInfo(
                phases[i].name,
                phases[i].path,
                processed,
                result.Count,
                i + 1,
                Math.Max(phases.Count, 1)));

            phases[i].action();
            processed++;

            report(new ScanProgressInfo(
                phases[i].name,
                phases[i].path,
                processed,
                result.Count,
                i + 1,
                Math.Max(phases.Count, 1)));
        }

        report(new ScanProgressInfo(
            "完成",
            "扫描完成",
            processed,
            result.Count,
            phases.Count + 1,
            Math.Max(phases.Count, 1)));
    }

    private static void ScanProjectJunk(
        string root,
        List<CleanupItem> result,
        ScanSession session)
    {
        if (!Directory.Exists(root)) return;

        var stack = new Stack<(string path, int depth)>();
        stack.Push((root, 0));

        while (stack.Count > 0)
        {
            session.Checkpoint();
            var (path, depth) = stack.Pop();
            if (depth > 6) continue;

            foreach (var dir in SafeDirectories(path))
            {
                session.Checkpoint();

                string name = Path.GetFileName(dir);
                if (name.Equals(".git", StringComparison.OrdinalIgnoreCase))
                    continue;

                if (ProjectJunkNames.Contains(name, StringComparer.OrdinalIgnoreCase))
                {
                    long size = SafeSize(dir, session);
                    if (size >= 50L * 1024 * 1024)
                    {
                        result.Add(new CleanupItem
                        {
                            Name = name,
                            Size = size,
                            Category = "项目垃圾",
                            Recommendation = "推荐清理",
                            Path = dir,
                            CanDelete = true,
                            IsDirectory = true,
                            Checked = true
                        });
                    }
                    continue;
                }

                stack.Push((dir, depth + 1));
            }
        }
    }

    private static IEnumerable<string> DefaultProjectRoots()
    {
        string home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        string[] roots =
        [
            Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),
            Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),
            Path.Combine(home, "Downloads"),
            Path.Combine(home, "Work")
        ];

        return roots.Where(Directory.Exists).Distinct();
    }

    private static IEnumerable<string> DefaultLargeRoots()
    {
        string home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        return
        [
            Path.Combine(home, "Downloads"),
            Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),
            Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),
            Environment.GetFolderPath(Environment.SpecialFolder.MyVideos),
            Path.Combine(home, "Work")
        ];
    }

    private static IEnumerable<string> SafeEntries(string root)
    {
        try
        {
            return Directory.EnumerateFileSystemEntries(root).ToArray();
        }
        catch
        {
            return Array.Empty<string>();
        }
    }

    private static IEnumerable<string> SafeDirectories(string root)
    {
        try
        {
            return Directory.EnumerateDirectories(root).ToArray();
        }
        catch
        {
            return Array.Empty<string>();
        }
    }

    private static IEnumerable<string> SafeFilesRecursive(
        string root,
        ScanSession session)
    {
        var stack = new Stack<string>();
        stack.Push(root);

        while (stack.Count > 0)
        {
            session.Checkpoint();
            string dir = stack.Pop();

            string[] subdirs;
            try { subdirs = Directory.GetDirectories(dir); }
            catch { subdirs = Array.Empty<string>(); }

            foreach (string sub in subdirs)
            {
                string name = Path.GetFileName(sub);
                if (name.Equals(".git", StringComparison.OrdinalIgnoreCase) ||
                    name.Equals("node_modules", StringComparison.OrdinalIgnoreCase))
                    continue;

                stack.Push(sub);
            }

            string[] files;
            try { files = Directory.GetFiles(dir); }
            catch { files = Array.Empty<string>(); }

            foreach (string file in files)
                yield return file;
        }
    }

    private static long SafeSize(string path, ScanSession session)
    {
        try
        {
            if (File.Exists(path)) return new FileInfo(path).Length;
            if (!Directory.Exists(path)) return 0;

            long total = 0;
            foreach (string file in SafeFilesRecursive(path, session))
            {
                session.Checkpoint();
                total += SafeFileSize(file);
            }
            return total;
        }
        catch
        {
            return 0;
        }
    }

    private static long SafeFileSize(string path)
    {
        try { return new FileInfo(path).Length; }
        catch { return 0; }
    }

    private static bool IsOlderThan(string path, TimeSpan age)
    {
        try
        {
            DateTime time = File.Exists(path)
                ? File.GetLastWriteTime(path)
                : Directory.GetLastWriteTime(path);
            return DateTime.Now - time >= age;
        }
        catch
        {
            return false;
        }
    }

    private static string NormalizeName(string value)
    {
        var chars = value
            .Where(char.IsLetterOrDigit)
            .Select(char.ToLowerInvariant)
            .ToArray();

        return new string(chars);
    }
}
