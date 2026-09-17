// ╔══════════════════════════════════════════════════════════════════╗
// ║  Mosgarage Agent — workspace-side daemon                         ║
// ║  Connects to control plane via /var/run/mosgarage.sock (MGP)     ║
// ║  Sends heartbeats, receives commands, forwards port info         ║
// ╚══════════════════════════════════════════════════════════════════╝

using System.Diagnostics;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Hosting;
using Mosgarage.Shared.Protocol;
using Serilog;

Log.Logger = new LoggerConfiguration()
    .WriteTo.Console(outputTemplate: "[{Timestamp:HH:mm:ss} {Level:u3}] [agent] {Message:lj}{NewLine}{Exception}")
    .WriteTo.File("/var/log/mosgarage/agent.log", rollingInterval: RollingInterval.Day)
    .CreateLogger();

// ── Read environment ─────────────────────────────────────────────
var workspaceId  = Guid.Parse(Environment.GetEnvironmentVariable("MOSGARAGE_WORKSPACE_ID")  ?? Guid.Empty.ToString());
var agentToken   = Environment.GetEnvironmentVariable("MOSGARAGE_AGENT_TOKEN")   ?? "";
var tunnelDna    = Environment.GetEnvironmentVariable("MOSGARAGE_TUNNEL_DNA")    ?? "";
var serverUrl    = Environment.GetEnvironmentVariable("MOSGARAGE_SERVER_URL")    ?? "http://localhost:7070";
var socketPath   = "/var/run/mosgarage.sock";
var heartbeatSec = int.Parse(Environment.GetEnvironmentVariable("MOSGARAGE_HEARTBEAT_INTERVAL") ?? "30");

Log.Information("mosgarage agent starting — workspace={Id} tunnel={Dna}", workspaceId, tunnelDna);

var cts = new CancellationTokenSource();
Console.CancelKeyPress += (_, e) => { e.Cancel = true; cts.Cancel(); };

await RunAgentAsync(cts.Token);

async Task RunAgentAsync(CancellationToken ct)
{
    while (!ct.IsCancellationRequested)
    {
        try
        {
            await ConnectAndRunAsync(ct);
        }
        catch (OperationCanceledException) { break; }
        catch (Exception ex)
        {
            Log.Warning(ex, "MGP connection lost — retrying in 5s");
            await Task.Delay(5000, ct);
        }
    }
    Log.Information("Agent shutting down.");
}

async Task ConnectAndRunAsync(CancellationToken ct)
{
    // Wait for socket to appear (control plane may still be booting)
    for (var i = 0; i < 30 && !File.Exists(socketPath); i++)
    {
        Log.Debug("Waiting for socket {Path}...", socketPath);
        await Task.Delay(2000, ct);
    }

    if (!File.Exists(socketPath))
        throw new FileNotFoundException($"Socket not found: {socketPath}");

    using var socket = new Socket(AddressFamily.Unix, SocketType.Stream, ProtocolType.Unspecified);
    await socket.ConnectAsync(new UnixDomainSocketEndPoint(socketPath), ct);

    await using var stream = new NetworkStream(socket, ownsSocket: false);
    using var reader = new StreamReader(stream, Encoding.UTF8, leaveOpen: true);

    Log.Information("Connected to control plane via {Path}", socketPath);

    // ── Send Hello ────────────────────────────────────────────────
    await SendAsync(stream, new MgpMessage
    {
        Type        = MgpMessageType.AgentHello,
        AgentToken  = agentToken,
        WorkspaceId = workspaceId,
    }, ct);

    // Wait for ServerAck
    var ackLine = await reader.ReadLineAsync(ct);
    var ack     = ackLine is not null ? JsonSerializer.Deserialize<MgpMessage>(ackLine) : null;
    if (ack?.Type != MgpMessageType.ServerAck)
        throw new Exception("Handshake failed — no ServerAck");

    Log.Information("Handshake complete — agent is live");

    // ── Start heartbeat loop + command listener concurrently ──────
    using var heartbeatCts = CancellationTokenSource.CreateLinkedTokenSource(ct);
    var heartbeatTask = HeartbeatLoopAsync(stream, heartbeatCts.Token);
    var commandTask   = CommandListenerAsync(reader, heartbeatCts.Token);

    await Task.WhenAny(heartbeatTask, commandTask);
    await heartbeatCts.CancelAsync();
}

async Task HeartbeatLoopAsync(Stream stream, CancellationToken ct)
{
    while (!ct.IsCancellationRequested)
    {
        await Task.Delay(heartbeatSec * 1000, ct);

        var hb = CollectMetrics();
        await SendAsync(stream, new MgpMessage
        {
            Type        = MgpMessageType.Heartbeat,
            WorkspaceId = workspaceId,
            Heartbeat   = hb,
        }, ct);

        Log.Debug("Heartbeat sent cpu={Cpu:0.0}% mem={Mem}MB ports={Ports}",
            hb.CpuPercent,
            hb.MemoryBytes / 1024 / 1024,
            hb.Ports.Count);
    }
}

async Task CommandListenerAsync(StreamReader reader, CancellationToken ct)
{
    while (!ct.IsCancellationRequested)
    {
        var line = await reader.ReadLineAsync(ct);
        if (line is null) break;

        MgpMessage? msg;
        try { msg = JsonSerializer.Deserialize<MgpMessage>(line); }
        catch { continue; }
        if (msg is null) continue;

        switch (msg.Type)
        {
            case MgpMessageType.CmdStop:
                Log.Information("[cmd] Stop received — shutting down");
                cts.Cancel();
                break;

            case MgpMessageType.CmdRestart:
                var proc = msg.Command?.Args.FirstOrDefault() ?? "all";
                Log.Information("[cmd] Restart {Process}", proc);
                RestartProcess(proc);
                break;

            case MgpMessageType.CmdExec:
                if (msg.Command is not null)
                    _ = ExecAsync(msg.Command.Command, msg.Command.Args, ct);
                break;

            case MgpMessageType.CmdSyncNow:
                Log.Information("[cmd] Git sync requested");
                File.WriteAllText("/tmp/mosgarage-git-push-now", "");
                break;
        }
    }
}

AgentHeartbeatPayload CollectMetrics()
{
    // CPU — average over 1 second
    double cpu = 0;
    try
    {
        var before   = Process.GetCurrentProcess();
        var cpuBefore = before.TotalProcessorTime;
        Thread.Sleep(500);
        var after    = Process.GetCurrentProcess();
        var cpuAfter  = after.TotalProcessorTime;
        cpu = (cpuAfter - cpuBefore).TotalMilliseconds / 5 / Environment.ProcessorCount;
    }
    catch { /* ignore on unsupported platforms */ }

    // Memory
    var proc  = Process.GetCurrentProcess();
    var memRss = proc.WorkingSet64;

    // Open ports
    var ports = GetListeningPorts();

    // Disk
    long diskFree = 0;
    try { diskFree = new DriveInfo("/").AvailableFreeSpace; } catch { }

    return new AgentHeartbeatPayload
    {
        AgentVersion   = "1.0.0",
        CpuPercent     = Math.Round(cpu, 2),
        MemoryBytes    = memRss,
        DiskFreeBytes  = diskFree,
        OpenFiles      = proc.HandleCount,
        Ports          = ports,
    };
}

List<PortInfo> GetListeningPorts()
{
    var ports = new List<PortInfo>();
    try
    {
        var output = RunShell("ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null");
        foreach (var line in output.Split('\n').Skip(1))
        {
            var parts = line.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length < 4) continue;
            var addr = parts.Length > 3 ? parts[3] : "";
            if (addr.Contains(':'))
            {
                var portStr = addr.Split(':').Last();
                if (int.TryParse(portStr, out var port) && port > 0)
                    ports.Add(new PortInfo { Port = port, Protocol = "tcp" });
            }
        }
    }
    catch { }
    return ports.DistinctBy(p => p.Port).ToList();
}

string RunShell(string cmd)
{
    var psi = new ProcessStartInfo("/bin/bash", $"-c \"{cmd}\"")
    {
        RedirectStandardOutput = true,
        UseShellExecute        = false,
    };
    using var p = Process.Start(psi)!;
    var output   = p.StandardOutput.ReadToEnd();
    p.WaitForExit();
    return output;
}

void RestartProcess(string name)
{
    try { RunShell($"supervisorctl restart {name} 2>/dev/null || pm2 restart {name} 2>/dev/null"); }
    catch (Exception ex) { Log.Warning(ex, "Restart {Name} failed", name); }
}

async Task ExecAsync(string cmd, string[] args, CancellationToken ct)
{
    var fullCmd = $"{cmd} {string.Join(' ', args)}";
    Log.Information("[exec] {Cmd}", fullCmd);
    try
    {
        var output = RunShell(fullCmd);
        Log.Information("[exec] output: {Output}", output.Trim());
    }
    catch (Exception ex) { Log.Warning(ex, "[exec] failed"); }
}

async Task SendAsync(Stream stream, MgpMessage msg, CancellationToken ct)
{
    var frame = Encoding.UTF8.GetBytes(JsonSerializer.Serialize(msg) + "\n");
    await stream.WriteAsync(frame, ct);
}
