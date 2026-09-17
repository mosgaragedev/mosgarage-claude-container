using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using Mosgarage.Server.Models;
using Mosgarage.Shared.Protocol;

namespace Mosgarage.Server.Services;

/// <summary>
/// Manages the Unix domain socket at /var/run/mosgarage.sock.
/// Workspace agents connect here to send heartbeats and receive commands.
/// This is the Mosgarage Protocol (MGP) — lightweight JSON-framed messages over a Unix socket.
/// </summary>
public sealed class UnixSocketService : IDisposable
{
    private const string SocketPath = "/var/run/mosgarage.sock";
    private readonly ILogger<UnixSocketService> _log;

    // Connected agents: agentToken → AgentConnection
    private readonly Dictionary<string, AgentConnection> _agents = new();
    private readonly SemaphoreSlim _lock = new(1, 1);

    public event Func<AgentHeartbeat, Task>? OnHeartbeat;

    public UnixSocketService(ILogger<UnixSocketService> log)
    {
        _log = log;
    }

    public async Task RegisterAgentAsync(AgentConnection conn)
    {
        await _lock.WaitAsync();
        try { _agents[conn.Token] = conn; }
        finally { _lock.Release(); }

        _log.LogInformation("[mgp] Agent registered token={Prefix}… workspace={Id}",
            conn.Token[..8], conn.WorkspaceId);
    }

    public async Task UnregisterAgentAsync(string token)
    {
        await _lock.WaitAsync();
        try { _agents.Remove(token); }
        finally { _lock.Release(); }
    }

    public async Task SendCommandAsync(string token, MgpMessage msg)
    {
        await _lock.WaitAsync();
        AgentConnection? conn;
        try { _agents.TryGetValue(token, out conn); }
        finally { _lock.Release(); }

        if (conn is null)
        {
            _log.LogWarning("[mgp] No agent with token {Prefix}…", token[..8]);
            return;
        }

        var frame = Encoding.UTF8.GetBytes(JsonSerializer.Serialize(msg) + "\n");
        await conn.Stream.WriteAsync(frame);
    }

    public async Task BroadcastAsync(MgpMessage msg)
    {
        await _lock.WaitAsync();
        var all = _agents.Values.ToList();
        _lock.Release();

        var frame = Encoding.UTF8.GetBytes(JsonSerializer.Serialize(msg) + "\n");
        foreach (var conn in all)
        {
            try { await conn.Stream.WriteAsync(frame); }
            catch (Exception ex) { _log.LogWarning(ex, "[mgp] Broadcast failed for {Id}", conn.WorkspaceId); }
        }
    }

    public async Task<int> ConnectedAgentCountAsync()
    {
        await _lock.WaitAsync();
        try { return _agents.Count; }
        finally { _lock.Release(); }
    }

    public async Task HandleHeartbeatAsync(AgentHeartbeat hb)
    {
        if (OnHeartbeat is not null)
            await OnHeartbeat(hb);
    }

    public void Dispose()
    {
        _lock.Dispose();
        // Clean up socket file
        if (File.Exists(SocketPath))
            File.Delete(SocketPath);
    }
}

// ── Agent socket listener (IHostedService) ────────────────────────
public sealed class AgentSocketListener(
    UnixSocketService socket,
    ILogger<AgentSocketListener> log,
    IServiceScopeFactory scopeFactory)
    : BackgroundService
{
    private const string SocketPath = "/var/run/mosgarage.sock";

    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        // Clean up stale socket
        if (File.Exists(SocketPath)) File.Delete(SocketPath);

        var listener = new Socket(AddressFamily.Unix, SocketType.Stream, ProtocolType.Unspecified);
        listener.Bind(new UnixDomainSocketEndPoint(SocketPath));
        listener.Listen(128);
        File.SetUnixFileMode(SocketPath,
            UnixFileMode.UserRead | UnixFileMode.UserWrite |
            UnixFileMode.GroupRead | UnixFileMode.GroupWrite |
            UnixFileMode.OtherRead | UnixFileMode.OtherWrite);

        log.LogInformation("[mgp] Listening on {Path}", SocketPath);

        while (!ct.IsCancellationRequested)
        {
            try
            {
                var client = await listener.AcceptAsync(ct);
                _ = Task.Run(() => HandleClientAsync(client, ct), ct);
            }
            catch (OperationCanceledException) { break; }
            catch (Exception ex)
            {
                log.LogError(ex, "[mgp] Accept error");
                await Task.Delay(1000, ct);
            }
        }

        listener.Close();
        if (File.Exists(SocketPath)) File.Delete(SocketPath);
    }

    private async Task HandleClientAsync(Socket client, CancellationToken ct)
    {
        await using var stream = new NetworkStream(client, ownsSocket: true);
        using var reader = new StreamReader(stream, Encoding.UTF8, leaveOpen: true);

        AgentConnection? conn = null;

        try
        {
            while (!ct.IsCancellationRequested)
            {
                var line = await reader.ReadLineAsync(ct);
                if (line is null) break;

                MgpMessage? msg;
                try { msg = JsonSerializer.Deserialize<MgpMessage>(line); }
                catch { log.LogWarning("[mgp] Malformed frame"); continue; }
                if (msg is null) continue;

                switch (msg.Type)
                {
                    case MgpMessageType.AgentHello:
                        conn = new AgentConnection
                        {
                            Token       = msg.AgentToken ?? "",
                            WorkspaceId = msg.WorkspaceId ?? Guid.Empty,
                            Stream      = stream,
                            ConnectedAt = DateTimeOffset.UtcNow,
                        };
                        await socket.RegisterAgentAsync(conn);

                        // Ack
                        var ack = JsonSerializer.Serialize(new MgpMessage
                        {
                            Type      = MgpMessageType.ServerAck,
                            Timestamp = DateTimeOffset.UtcNow,
                        }) + "\n";
                        await stream.WriteAsync(Encoding.UTF8.GetBytes(ack), ct);
                        break;

                    case MgpMessageType.Heartbeat:
                        if (msg.Heartbeat is not null)
                            await socket.HandleHeartbeatAsync(msg.Heartbeat);
                        break;

                    case MgpMessageType.AgentBye:
                        if (conn is not null)
                            await socket.UnregisterAgentAsync(conn.Token);
                        return;
                }
            }
        }
        catch (Exception ex) when (ex is not OperationCanceledException)
        {
            log.LogWarning(ex, "[mgp] Client handler error");
        }
        finally
        {
            if (conn is not null)
                await socket.UnregisterAgentAsync(conn.Token);
        }
    }
}

public sealed class AgentConnection
{
    public string          Token       { get; init; } = "";
    public Guid            WorkspaceId { get; init; }
    public Stream          Stream      { get; init; } = Stream.Null;
    public DateTimeOffset  ConnectedAt { get; init; }
}
