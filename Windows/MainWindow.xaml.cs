using Microsoft.VisualBasic.FileIO;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Data;
using System.Windows.Media;

namespace SafeMacCleaner.Windows;

public partial class MainWindow : Window
{
    private PageKind _page = PageKind.Smart;
    private PageKind? _scanOwner;
    private ScanSession? _scanSession;
    private DateTime _scanStart;
    private readonly System.Windows.Threading.DispatcherTimer _timer;

    private readonly Dictionary<PageKind, ObservableCollection<CleanupItem>> _cleanup =
        new()
        {
            [PageKind.Smart] = new(),
            [PageKind.Large] = new(),
            [PageKind.Leftovers] = new(),
            [PageKind.Related] = new()
        };

    private readonly Dictionary<PageKind, bool> _hasScanned =
        new()
        {
            [PageKind.Smart] = false,
            [PageKind.Large] = false,
            [PageKind.Apps] = false,
            [PageKind.Leftovers] = false,
            [PageKind.Related] = false
        };

    private ObservableCollection<AppItem> _apps = new();
    private AppItem? _selectedApp;
    private ScanProgressInfo? _latestProgress;

    public MainWindow()
    {
        InitializeComponent();

        _timer = new System.Windows.Threading.DispatcherTimer
        {
            Interval = TimeSpan.FromMilliseconds(500)
        };
        _timer.Tick += (_, _) => RefreshScanMetricsOnly();

        ConfigureCleanupColumns();
        RenderPage();
    }

    private bool IsScanning => _scanSession is not null;

    private void Navigation_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not RadioButton rb || rb.Tag is not string tag)
            return;

        _page = tag switch
        {
            "Large" => PageKind.Large,
            "Apps" => PageKind.Apps,
            "Leftovers" => PageKind.Leftovers,
            _ => PageKind.Smart
        };

        RenderPage();
    }

    private async void MainAction_Click(object sender, RoutedEventArgs e)
    {
        if (IsScanning) return;

        if (!_hasScanned[_page])
        {
            await StartScanAsync(_page);
            return;
        }

        if (_page == PageKind.Apps)
        {
            if (ResultsGrid.SelectedItem is not AppItem app)
            {
                MessageBox.Show(
                    this,
                    "请先选择一个应用。",
                    "应用卸载",
                    MessageBoxButton.OK,
                    MessageBoxImage.Information);
                return;
            }

            _selectedApp = app;
            _page = PageKind.Related;
            _hasScanned[PageKind.Related] = false;
            _cleanup[PageKind.Related].Clear();

            PageTitle.Text = $"完整卸载：{app.Name}";
            PageSubtitle.Text = "精确名称匹配默认勾选；宽松匹配项默认不勾选。";
            BadgeText.Text = "完整卸载";

            await StartScanAsync(PageKind.Related);
            return;
        }

        await RecycleSelectedAsync();
    }

    private async void ScanControl_Click(object sender, RoutedEventArgs e)
    {
        if (IsScanning)
        {
            CancelCurrentScan();
            return;
        }

        await StartScanAsync(_page);
    }

    private void Pause_Click(object sender, RoutedEventArgs e)
    {
        if (_scanSession is null) return;

        bool paused = _scanSession.TogglePause();
        PauseButton.Content = paused ? "继续" : "暂停";

        if (paused)
            StatusText.Text = $"{ScanOwnerName()}已暂停 · 可切换页面或取消扫描";
        else
            StatusText.Text = $"{ScanOwnerName()}正在后台扫描 · 可切换页面，进度不会中断";

        RefreshScanMetricsOnly();
    }

    private async Task StartScanAsync(PageKind owner)
    {
        if (IsScanning) return;

        _scanOwner = owner;
        _scanSession = new ScanSession();
        _latestProgress = null;
        _scanStart = DateTime.Now;

        PauseButton.Content = "暂停";
        PauseButton.Visibility = Visibility.Visible;
        ScanControlButton.Content = "取消扫描";
        ScanControlButton.Visibility = Visibility.Visible;
        ScanControlButton.IsEnabled = true;

        _timer.Start();
        RenderPage();

        try
        {
            IProgress<ScanProgressInfo> progress = new Progress<ScanProgressInfo>(p =>
            {
                _latestProgress = p;
                RenderProgress(p);
            });

            if (owner == PageKind.Smart)
            {
                var data = await Task.Run(() =>
                    ScanEngine.ScanSmart(_scanSession, progress.Report));
                ReplaceCleanup(PageKind.Smart, data);
                _hasScanned[PageKind.Smart] = true;
            }
            else if (owner == PageKind.Large)
            {
                var data = await Task.Run(() =>
                    ScanEngine.ScanLarge(_scanSession, progress.Report));
                ReplaceCleanup(PageKind.Large, data);
                _hasScanned[PageKind.Large] = true;
            }
            else if (owner == PageKind.Apps)
            {
                var data = await Task.Run(() =>
                    ScanEngine.ScanApps(_scanSession, progress.Report));
                _apps = new ObservableCollection<AppItem>(data);
                _hasScanned[PageKind.Apps] = true;
            }
            else if (owner == PageKind.Leftovers)
            {
                if (!_hasScanned[PageKind.Apps])
                {
                    var appData = await Task.Run(() =>
                        ScanEngine.ScanApps(_scanSession, progress.Report));
                    _apps = new ObservableCollection<AppItem>(appData);
                    _hasScanned[PageKind.Apps] = true;
                }

                var data = await Task.Run(() =>
                    ScanEngine.ScanLeftovers(_apps, _scanSession, progress.Report));
                ReplaceCleanup(PageKind.Leftovers, data);
                _hasScanned[PageKind.Leftovers] = true;
            }
            else if (owner == PageKind.Related && _selectedApp is not null)
            {
                var data = await Task.Run(() =>
                    ScanEngine.ScanRelated(_selectedApp, _scanSession, progress.Report));
                ReplaceCleanup(PageKind.Related, data);
                _hasScanned[PageKind.Related] = true;
            }
        }
        catch (OperationCanceledException)
        {
            StatusText.Text = "扫描已取消";
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                this,
                ex.Message,
                "扫描失败",
                MessageBoxButton.OK,
                MessageBoxImage.Warning);
        }
        finally
        {
            _timer.Stop();
            _scanSession?.Dispose();
            _scanSession = null;
            _scanOwner = null;

            PauseButton.Visibility = Visibility.Collapsed;
            ScanControlButton.Content = NormalScanButtonTitle();

            RenderPage();
        }
    }

    private void CancelCurrentScan()
    {
        if (_scanSession is null) return;

        _scanSession.Cancel();
        PauseButton.IsEnabled = false;
        ScanControlButton.Content = "正在取消…";
        ScanControlButton.IsEnabled = false;
        StatusText.Text = "正在停止扫描，请等待当前文件操作结束…";
    }

    private async Task RecycleSelectedAsync()
    {
        if (_page == PageKind.Apps) return;

        var selected = _cleanup[_page]
            .Where(x => x.Checked && x.CanDelete)
            .ToList();

        if (selected.Count == 0)
        {
            MessageBox.Show(
                this,
                "请先勾选要处理的项目。",
                "没有已勾选项目",
                MessageBoxButton.OK,
                MessageBoxImage.Information);
            return;
        }

        long total = selected.Sum(x => x.Size);
        var confirm = MessageBox.Show(
            this,
            $"共 {selected.Count} 项，约 {Format.Bytes(total)}。\n\n" +
            "将移动到 Windows 回收站，可以恢复。",
            "确认清理？",
            MessageBoxButton.OKCancel,
            MessageBoxImage.Warning);

        if (confirm != MessageBoxResult.OK) return;

        var failed = new List<string>();

        await Task.Run(() =>
        {
            foreach (var item in selected)
            {
                try
                {
                    if (item.IsDirectory)
                    {
                        FileSystem.DeleteDirectory(
                            item.Path,
                            UIOption.OnlyErrorDialogs,
                            RecycleOption.SendToRecycleBin);
                    }
                    else
                    {
                        FileSystem.DeleteFile(
                            item.Path,
                            UIOption.OnlyErrorDialogs,
                            RecycleOption.SendToRecycleBin);
                    }
                }
                catch (Exception ex)
                {
                    failed.Add($"{item.Name}：{ex.Message}");
                }
            }
        });

        foreach (var item in selected)
        {
            if (!failed.Any(x => x.StartsWith(item.Name + "：")))
                _cleanup[_page].Remove(item);
        }

        RenderPage();

        if (failed.Count > 0)
        {
            MessageBox.Show(
                this,
                string.Join(Environment.NewLine, failed.Take(6)),
                "部分项目未能移动",
                MessageBoxButton.OK,
                MessageBoxImage.Warning);
        }
    }

    private void ReplaceCleanup(PageKind page, IEnumerable<CleanupItem> data)
    {
        var collection = new ObservableCollection<CleanupItem>(data);
        foreach (var item in collection)
            item.PropertyChanged += (_, _) => Dispatcher.Invoke(RenderPage);

        _cleanup[page] = collection;
    }

    private void RenderPage()
    {
        switch (_page)
        {
            case PageKind.Smart:
                PageTitle.Text = "智能扫描";
                PageSubtitle.Text = "缓存、日志、开发缓存和项目可重建产物。";
                BadgeText.Text = "智能清理";
                SmartNav.IsChecked = true;
                ConfigureCleanupColumns();
                ResultsGrid.ItemsSource = _cleanup[PageKind.Smart];
                break;

            case PageKind.Large:
                PageTitle.Text = "大文件";
                PageSubtitle.Text = "默认扫描 ≥ 500 MB；仅人工判断，不默认勾选。";
                BadgeText.Text = "大文件筛选";
                LargeNav.IsChecked = true;
                ConfigureCleanupColumns();
                ResultsGrid.ItemsSource = _cleanup[PageKind.Large];
                break;

            case PageKind.Apps:
                PageTitle.Text = "应用卸载";
                PageSubtitle.Text = "扫描系统已安装应用，选择后分析 AppData / ProgramData 关联文件。";
                BadgeText.Text = "完整卸载";
                AppsNav.IsChecked = true;
                ConfigureAppColumns();
                ResultsGrid.ItemsSource = _apps;
                break;

            case PageKind.Leftovers:
                PageTitle.Text = "应用残留";
                PageSubtitle.Text = "保守识别可能没有对应已安装应用的 AppData / ProgramData 目录。";
                BadgeText.Text = "残留识别";
                LeftoversNav.IsChecked = true;
                ConfigureCleanupColumns();
                ResultsGrid.ItemsSource = _cleanup[PageKind.Leftovers];
                break;

            case PageKind.Related:
                PageTitle.Text = _selectedApp is null
                    ? "完整卸载"
                    : $"完整卸载：{_selectedApp.Name}";
                PageSubtitle.Text = "精确名称匹配默认勾选；宽松匹配项默认不勾选。";
                BadgeText.Text = "完整卸载";
                AppsNav.IsChecked = true;
                ConfigureCleanupColumns();
                ResultsGrid.ItemsSource = _cleanup[PageKind.Related];
                break;
        }

        RenderMetricsAndButtons();
        RefreshDiskFree();
    }

    private void RenderMetricsAndButtons()
    {
        bool scanned = _hasScanned[_page];

        if (_page == PageKind.Apps)
        {
            if (!scanned)
            {
                MetricCandidate.Text = "—";
                MetricCandidateSub.Text = "尚未扫描";
                MetricSelected.Text = "—";
                MetricSelectedSub.Text = "等待扫描";
                MetricFound.Text = "0";
                MetricFoundSub.Text = "已安装应用";
            }
            else
            {
                long total = _apps.Sum(x => x.Size);
                var selected = ResultsGrid.SelectedItem as AppItem;

                MetricCandidate.Text = Format.Bytes(total);
                MetricCandidateSub.Text = "已安装 App 总体积";
                MetricSelected.Text = selected?.SizeText ?? "—";
                MetricSelectedSub.Text = "当前选择";
                MetricFound.Text = _apps.Count.ToString();
                MetricFoundSub.Text = "已安装应用";
            }
        }
        else
        {
            var data = _cleanup[_page];

            if (!scanned)
            {
                MetricCandidate.Text = "—";
                MetricCandidateSub.Text = "尚未扫描";
                MetricSelected.Text = "—";
                MetricSelectedSub.Text = "等待扫描";
                MetricFound.Text = "0";
                MetricFoundSub.Text = "扫描结果";
            }
            else
            {
                long candidate = data.Where(x => x.CanDelete).Sum(x => x.Size);
                var selectedItems = data.Where(x => x.Checked && x.CanDelete).ToList();
                long selected = selectedItems.Sum(x => x.Size);

                MetricCandidate.Text = Format.Bytes(candidate);
                MetricCandidateSub.Text = "当前页面候选";
                MetricSelected.Text = Format.Bytes(selected);
                MetricSelectedSub.Text = $"{selectedItems.Count} 项将处理";
                MetricFound.Text = data.Count.ToString();
                MetricFoundSub.Text = "发现项目";
            }
        }

        if (IsScanning)
        {
            MainActionButton.Content = "后台扫描中…";
            MainActionButton.IsEnabled = false;

            ScanControlButton.Content = "取消扫描";
            ScanControlButton.Visibility = Visibility.Visible;
            ScanControlButton.IsEnabled = true;
            PauseButton.Visibility = Visibility.Visible;
            PauseButton.IsEnabled = true;

            StatusText.Text = $"{ScanOwnerName()}正在后台扫描 · 可切换页面，进度不会中断";
            return;
        }

        PauseButton.Visibility = Visibility.Collapsed;

        if (!scanned)
        {
            MainActionButton.Content = _page switch
            {
                PageKind.Smart => "开始智能扫描",
                PageKind.Large => "扫描大文件",
                PageKind.Apps => "扫描应用",
                PageKind.Leftovers => "扫描应用残留",
                PageKind.Related => "分析关联文件",
                _ => "开始扫描"
            };
            MainActionButton.IsEnabled = true;
            ScanControlButton.Visibility = Visibility.Collapsed;

            StatusText.Text = _page switch
            {
                PageKind.Smart => "尚未扫描 · 点击主按钮开始智能扫描",
                PageKind.Large => "尚未扫描 · 点击主按钮开始查找大文件",
                PageKind.Apps => "尚未扫描 · 点击主按钮开始扫描应用",
                PageKind.Leftovers => "尚未扫描 · 点击主按钮开始扫描残留",
                _ => "尚未分析 · 点击主按钮开始分析"
            };
            return;
        }

        ScanControlButton.Visibility = Visibility.Visible;
        ScanControlButton.Content = NormalScanButtonTitle();
        ScanControlButton.IsEnabled = true;

        if (_page == PageKind.Apps)
        {
            MainActionButton.Content =
                ResultsGrid.SelectedItem is AppItem ? "分析卸载" : "请选择 App";
            MainActionButton.IsEnabled = ResultsGrid.SelectedItem is AppItem;
            StatusText.Text = $"已找到 {_apps.Count} 个应用";
            return;
        }

        var items = _cleanup[_page];
        var checkedItems = items.Where(x => x.Checked && x.CanDelete).ToList();
        long selectedBytes = checkedItems.Sum(x => x.Size);

        MainActionButton.Content = _page == PageKind.Related
            ? selectedBytes > 0
                ? $"卸载并清理 {Format.Bytes(selectedBytes)}"
                : "勾选后卸载"
            : selectedBytes > 0
                ? $"立即清理 {Format.Bytes(selectedBytes)}"
                : "勾选后清理";

        MainActionButton.IsEnabled = selectedBytes > 0;
        StatusText.Text =
            $"{items.Count} 项 · 已勾选 {checkedItems.Count} 项 / {Format.Bytes(selectedBytes)}";
    }

    private void RenderProgress(ScanProgressInfo progress)
    {
        ScanPathText.Text = $"当前：{CompactPath(progress.CurrentPath)}";
        ScanPathText.ToolTip = progress.CurrentPath;

        double available = Math.Max(0, ActualWidth - 236 - 48);
        ProgressFill.Width = available * progress.Fraction;

        ScanMetricsText.Text =
            $"阶段 {Math.Min(progress.PhaseIndex, progress.PhaseCount)}/{progress.PhaseCount}" +
            $" · {progress.PercentText}" +
            $" · 已扫描 {progress.Processed}" +
            $" · 已发现 {progress.Found}" +
            $" · 用时 {ElapsedText()}";
    }

    private void RefreshScanMetricsOnly()
    {
        if (_latestProgress is null) return;

        string state = _scanSession?.IsPaused == true
            ? "已暂停"
            : _latestProgress.PercentText;

        ScanMetricsText.Text =
            $"阶段 {Math.Min(_latestProgress.PhaseIndex, _latestProgress.PhaseCount)}/{_latestProgress.PhaseCount}" +
            $" · {state}" +
            $" · 已扫描 {_latestProgress.Processed}" +
            $" · 已发现 {_latestProgress.Found}" +
            $" · 用时 {ElapsedText()}";
    }

    private string ScanOwnerName() => _scanOwner switch
    {
        PageKind.Smart => "智能扫描",
        PageKind.Large => "大文件",
        PageKind.Apps => "应用",
        PageKind.Leftovers => "应用残留",
        PageKind.Related => "关联文件",
        _ => "任务"
    };

    private string NormalScanButtonTitle() =>
        _page is PageKind.Apps or PageKind.Related
            ? "重新扫描 App"
            : "重新扫描";

    private string ElapsedText()
    {
        var elapsed = DateTime.Now - _scanStart;
        return elapsed.TotalHours >= 1
            ? elapsed.ToString(@"hh\:mm\:ss")
            : elapsed.ToString(@"mm\:ss");
    }

    private static string CompactPath(string path)
    {
        if (path == "扫描完成") return path;

        try
        {
            string file = Path.GetFileName(path);
            string? parent = Path.GetFileName(Path.GetDirectoryName(path));
            string value = string.IsNullOrWhiteSpace(parent)
                ? file
                : $"…/{parent}/{file}";

            return value.Length <= 82
                ? value
                : $"…/{parent}/…{file[^Math.Min(file.Length, 54)..]}";
        }
        catch
        {
            return path.Length <= 82 ? path : $"…{path[^78..]}";
        }
    }

    private void ConfigureCleanupColumns()
    {
        ResultsGrid.Columns.Clear();

        ResultsGrid.Columns.Add(new DataGridCheckBoxColumn
        {
            Header = "",
            Width = 42,
            Binding = new Binding(nameof(CleanupItem.Checked))
            {
                Mode = BindingMode.TwoWay,
                UpdateSourceTrigger = UpdateSourceTrigger.PropertyChanged
            }
        });

        ResultsGrid.Columns.Add(TextColumn("名称", nameof(CleanupItem.Name), 220));
        ResultsGrid.Columns.Add(TextColumn("大小", nameof(CleanupItem.SizeText), 100));
        ResultsGrid.Columns.Add(TextColumn("类型", nameof(CleanupItem.Category), 130));
        ResultsGrid.Columns.Add(TextColumn("建议", nameof(CleanupItem.Recommendation), 110));

        ResultsGrid.Columns.Add(new DataGridTextColumn
        {
            Header = "路径",
            Width = new DataGridLength(1, DataGridLengthUnitType.Star),
            Binding = new Binding(nameof(CleanupItem.Path))
        });
    }

    private void ConfigureAppColumns()
    {
        ResultsGrid.Columns.Clear();
        ResultsGrid.Columns.Add(TextColumn("应用", nameof(AppItem.Name), 230));
        ResultsGrid.Columns.Add(TextColumn("大小", nameof(AppItem.SizeText), 100));
        ResultsGrid.Columns.Add(TextColumn("版本", nameof(AppItem.Version), 100));
        ResultsGrid.Columns.Add(TextColumn("发布者", nameof(AppItem.Publisher), 180));

        ResultsGrid.Columns.Add(new DataGridTextColumn
        {
            Header = "安装位置",
            Width = new DataGridLength(1, DataGridLengthUnitType.Star),
            Binding = new Binding(nameof(AppItem.InstallLocation))
        });
    }

    private static DataGridTextColumn TextColumn(
        string header,
        string binding,
        double width)
    {
        return new DataGridTextColumn
        {
            Header = header,
            Width = width,
            Binding = new Binding(binding)
        };
    }

    private void ResultsGrid_SelectionChanged(
        object sender,
        SelectionChangedEventArgs e)
    {
        RenderMetricsAndButtons();
    }

    private void ResultsGrid_CurrentCellChanged(object? sender, EventArgs e)
    {
        Dispatcher.BeginInvoke(RenderMetricsAndButtons);
    }

    private void RefreshDiskFree()
    {
        try
        {
            string root = Path.GetPathRoot(
                Environment.GetFolderPath(Environment.SpecialFolder.UserProfile)) ?? "C:\\";
            var drive = new DriveInfo(root);
            DiskFreeSidebar.Text = $"剩余 {Format.Bytes(drive.AvailableFreeSpace)}";
        }
        catch
        {
            DiskFreeSidebar.Text = "";
        }
    }
}
