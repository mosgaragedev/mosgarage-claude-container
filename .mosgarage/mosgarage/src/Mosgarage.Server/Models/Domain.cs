// ── Mosgarage Domain Models ────────────────────────────────────────
namespace Mosgarage.Server.Models;

// ── Workspace ─────────────────────────────────────────────────────
public sealed class Workspace
{
    public Guid     Id              { get; set; } = Guid.NewGuid();
    public Guid     OwnerId         { get; set; }
    public Guid     TemplateId      { get; set; }
    public string   Name            { get; set; } = "";
    public string   DisplayName     { get; set; } = "";
    public string   ContainerId     { get; set; } = "";  // Docker container ID
    public string   ContainerName   { get; set; } = "";
    public string   TunnelDna       { get; set; } = ""; // ← unique hex slug → <dna>.try.mosgarage.app
    public string   AgentToken      { get; set; } = Guid.NewGuid().ToString("N");
    public WorkspaceStatus Status   { get; set; } = WorkspaceStatus.Pending;
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? LastActiveAt { get; set; }
    public DateTimeOffset? DeletedAt    { get; set; }
    public bool      AutoStop      { get; set; } = true;
    public int       AutoStopMinutes { get; set; } = 120;
    public Dictionary<string, string> Metadata { get; set; } = new();

    // Navigation
    public User?              Owner    { get; set; }
    public WorkspaceTemplate? Template { get; set; }
    public ICollection<WorkspaceBuild> Builds { get; set; } = new List<WorkspaceBuild>();
}

public enum WorkspaceStatus
{
    Pending    = 0,
    Starting   = 1,
    Running    = 2,
    Stopping   = 3,
    Stopped    = 4,
    Failed     = 5,
    Deleting   = 6,
    Deleted    = 7,
}

// ── Workspace Build (audit log of provisioning steps) ────────────
public sealed class WorkspaceBuild
{
    public Guid              Id          { get; set; } = Guid.NewGuid();
    public Guid              WorkspaceId { get; set; }
    public BuildReason        Reason     { get; set; }
    public BuildStatus        Status     { get; set; } = BuildStatus.Pending;
    public string             Logs       { get; set; } = "";
    public DateTimeOffset     CreatedAt  { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset?    CompletedAt { get; set; }
    public Workspace?         Workspace  { get; set; }
}

public enum BuildReason { Initiator = 0, Autostart = 1, Autostop = 2, Delete = 3 }
public enum BuildStatus { Pending = 0, Running = 1, Succeeded = 2, Failed = 3, Canceled = 4 }

// ── WorkspaceTemplate ─────────────────────────────────────────────
public sealed class WorkspaceTemplate
{
    public Guid   Id          { get; set; } = Guid.NewGuid();
    public string Name        { get; set; } = "";
    public string DisplayName { get; set; } = "";
    public string Description { get; set; } = "";
    public string Icon        { get; set; } = "🖥️";
    public string YamlContent { get; set; } = "";      // raw template YAML
    public string DockerImage { get; set; } = "docker.io/mosgarage/workspace:latest";
    public int    Version     { get; set; } = 1;
    public bool   IsActive    { get; set; } = true;
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
    public ICollection<Workspace> Workspaces { get; set; } = new List<Workspace>();
}

// ── User ──────────────────────────────────────────────────────────
public sealed class User
{
    public Guid   Id           { get; set; } = Guid.NewGuid();
    public string Email        { get; set; } = "";
    public string Username     { get; set; } = "";
    public string PasswordHash { get; set; } = "";
    public UserRole Role       { get; set; } = UserRole.Member;
    public bool   IsActive     { get; set; } = true;
    public DateTimeOffset CreatedAt  { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? LastLoginAt { get; set; }
    public ICollection<Workspace> Workspaces { get; set; } = new List<Workspace>();
    public ICollection<ApiKey> ApiKeys       { get; set; } = new List<ApiKey>();
}

public enum UserRole { Member = 0, Admin = 1 }

// ── ApiKey ───────────────────────────────────────────────────────
public sealed class ApiKey
{
    public Guid   Id        { get; set; } = Guid.NewGuid();
    public Guid   UserId    { get; set; }
    public string Name      { get; set; } = "";
    public string HashedKey { get; set; } = "";
    public string Prefix    { get; set; } = "";   // first 8 chars shown in UI
    public DateTimeOffset CreatedAt  { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset? ExpiresAt { get; set; }
    public DateTimeOffset? LastUsedAt { get; set; }
    public User? User { get; set; }
}

// ── AgentHeartbeat (written by agent, read by control plane) ─────
public sealed class AgentHeartbeat
{
    public Guid          WorkspaceId { get; set; }
    public string        Version     { get; set; } = "";
    public DateTimeOffset ReceivedAt { get; set; } = DateTimeOffset.UtcNow;
    public double        CpuUsage    { get; set; }
    public long          MemoryBytes { get; set; }
    public int           OpenFiles   { get; set; }
    public List<string>  ActivePorts { get; set; } = new();
}

// ── Options ──────────────────────────────────────────────────────
public sealed class MosgarageOptions
{
    public string AccessUrl        { get; set; } = "http://localhost:7070";
    public string? WildcardUrl     { get; set; }
    public string SecretKey        { get; set; } = "";
    public string PgConnection     { get; set; } = "";
    public string Provisioner      { get; set; } = "docker";
    public string WorkspaceNetwork { get; set; } = "mosgarage-net";
    public string WorkspaceImage   { get; set; } = "docker.io/mosgarage/workspace:latest";
    public string AdminEmail       { get; set; } = "admin@mosgarage.local";
    public string AdminPassword    { get; set; } = "changeme";
    public int    JwtExpiryHours   { get; set; } = 24;

    // env var mappings
    public string MOSGARAGE_ACCESS_URL     { set => AccessUrl     = value; }
    public string MOSGARAGE_WILDCARD_URL   { set => WildcardUrl   = value; }
    public string MOSGARAGE_SECRET_KEY     { set => SecretKey     = value; }
    public string MOSGARAGE_PG_CONNECTION  { set => PgConnection  = value; }
    public string MOSGARAGE_PROVISIONER    { set => Provisioner   = value; }
    public string MOSGARAGE_WORKSPACE_IMAGE { set => WorkspaceImage = value; }
    public string MOSGARAGE_ADMIN_EMAIL    { set => AdminEmail    = value; }
    public string MOSGARAGE_ADMIN_PASSWORD { set => AdminPassword = value; }
}
