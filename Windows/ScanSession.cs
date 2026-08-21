namespace SafeMacCleaner.Windows;

public sealed class ScanSession : IDisposable
{
    private readonly CancellationTokenSource _cts = new();
    private readonly ManualResetEventSlim _pauseGate = new(true);

    public CancellationToken Token => _cts.Token;
    public bool IsPaused { get; private set; }

    public void Pause()
    {
        if (_cts.IsCancellationRequested) return;
        IsPaused = true;
        _pauseGate.Reset();
    }

    public void Resume()
    {
        IsPaused = false;
        _pauseGate.Set();
    }

    public bool TogglePause()
    {
        if (IsPaused) Resume();
        else Pause();
        return IsPaused;
    }

    public void Cancel()
    {
        _cts.Cancel();
        _pauseGate.Set();
    }

    public void Checkpoint()
    {
        Token.ThrowIfCancellationRequested();
        _pauseGate.Wait(Token);
        Token.ThrowIfCancellationRequested();
    }

    public void Dispose()
    {
        _pauseGate.Dispose();
        _cts.Dispose();
    }
}
