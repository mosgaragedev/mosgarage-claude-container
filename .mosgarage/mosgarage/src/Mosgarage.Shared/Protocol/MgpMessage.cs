// Mosgarage Protocol (MGP)
// Newline-delimited JSON frames over Unix domain socket.
// Control plane ↔ workspace agents.

namespace Mosgarage.Shared.Protocol;

public sealed class MgpMessage
{
    public MgpMessageType   Type        { get; set; }
    public DateTimeOffset   Timestamp   { get; set; } = DateTimeOffset.UtcNow;
    public string?          AgentToken  { get; set; }
    public Guid?            WorkspaceId { get; set; }
    public AgentHeartbeatPayload? Heartbeat { get; set; }
    public ServerCommandPayload?  Command   { get; set; }
    public string?          Error       { get; set; }
}

public enum MgpMessageType
{
    // Agent → Server
    AgentHello  = 1,   // first message, includes token + workspace ID
    Heartbeat   = 2,   // periodic metrics report
    AgentBye    = 3,   // clean disconnect
    PortOpen    = 4,   // agent opened a new port
    PortClose   = 5,   // agent closed a port
    LogLine     = 6,   // agent forwards a log line

    // Server → Agent
    ServerAck   = 100, // hello acknowledged
    CmdStop     = 101, // graceful stop request
    CmdRestart  = 102, // restart a named process
    CmdExec     = 103, // run a shell command (result streamed back via LogLine)
    CmdSyncNow  = 104, // trigger immediate git sync
}

public sealed class AgentHeartbeatPayload
{
    public string  AgentVersion { get; set; } = "";
    public double  CpuPercent   { get; set; }
    public long    MemoryBytes  { get; set; }
    public long    DiskFreeBytes { get; set; }
    public int     OpenFiles    { get; set; }
    public List<PortInfo> Ports { get; set; } = new();
    public Dictionary<string, ProcessInfo> Processes { get; set; } = new();
}

public sealed class PortInfo
{
    public int    Port     { get; set; }
    public string Protocol { get; set; } = "tcp";
    public string? Label   { get; set; }
}

public sealed class ProcessInfo
{
    public string Name   { get; set; } = "";
    public int    Pid    { get; set; }
    public string Status { get; set; } = "";
    public double Cpu    { get; set; }
    public long   Mem    { get; set; }
}

public sealed class ServerCommandPayload
{
    public string   Command { get; set; } = "";
    public string[] Args    { get; set; } = Array.Empty<string>();
}

// ── Workspace state (shared model) ───────────────────────────────
public enum WorkspaceState
{
    Pending  = 0,
    Starting = 1,
    Running  = 2,
    Stopping = 3,
    Stopped  = 4,
    Failed   = 5,
    Deleted  = 6,
}
