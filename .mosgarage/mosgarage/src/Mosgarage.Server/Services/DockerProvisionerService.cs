using Docker.DotNet;
using Docker.DotNet.Models;
using Mosgarage.Server.Models;

namespace Mosgarage.Server.Services;

/// <summary>
/// Provisions workspace containers via the Docker Unix socket.
/// Mirrors how Coder's docker provisioner works, but tailored for mosgarage.
/// </summary>
public sealed class DockerProvisionerService : IDisposable
{
    private readonly DockerClient       _docker;
    private readonly MosgarageOptions   _opts;
    private readonly ILogger<DockerProvisionerService> _log;

    public DockerProvisionerService(MosgarageOptions opts,
        ILogger<DockerProvisionerService> log)
    {
        _opts   = opts;
        _log    = log;
        _docker = new DockerClientConfiguration(
            new Uri("unix:///var/run/docker.sock"))
            .CreateClient();
    }

    // ── Start workspace ──────────────────────────────────────────
    public async Task<string> StartWorkspaceAsync(Workspace ws, CancellationToken ct = default)
    {
        _log.LogInformation("Provisioning workspace {Name} ({Id})", ws.Name, ws.Id);

        var containerName = $"mosgarage-ws-{ws.Name}-{ws.Id:N[..8]}";
        var tunnelLabel   = $"{ws.TunnelDna}.ws";

        // Pull image if not present
        await EnsureImageAsync(ws.Template?.DockerImage ?? _opts.WorkspaceImage, ct);

        var response = await _docker.Containers.CreateContainerAsync(
            new CreateContainerParameters
            {
                Name  = containerName,
                Image = ws.Template?.DockerImage ?? _opts.WorkspaceImage,

                Env = new List<string>
                {
                    $"MOSGARAGE_WORKSPACE_ID={ws.Id}",
                    $"MOSGARAGE_AGENT_TOKEN={ws.AgentToken}",
                    $"MOSGARAGE_SERVER_URL={_opts.AccessUrl}",
                    $"MOSGARAGE_TUNNEL_DNA={ws.TunnelDna}",
                    $"CODE_SERVER_PASSWORD={ws.AgentToken[..12]}",
                    "NODE_ENV=production",
                },

                HostConfig = new HostConfig
                {
                    NetworkMode  = _opts.WorkspaceNetwork,
                    AutoRemove   = false,
                    RestartPolicy = new RestartPolicy { Name = RestartPolicyKind.UnlessStopped },
                    Memory       = 2L * 1024 * 1024 * 1024,   // 2 GB
                    NanoCPUs     = 2_000_000_000L,             // 2 vCPU
                    Binds        = new List<string>
                    {
                        // Agent inherits the control-plane Unix socket (read-only)
                        "/var/run/mosgarage.sock:/var/run/mosgarage.sock:ro",
                    },
                },

                Labels = new Dictionary<string, string>
                {
                    ["mosgarage.workspace.id"]      = ws.Id.ToString(),
                    ["mosgarage.workspace.name"]    = ws.Name,
                    ["mosgarage.workspace.owner"]   = ws.OwnerId.ToString(),
                    ["mosgarage.tunnel.dna"]        = ws.TunnelDna,
                    // Traefik dynamic routing labels
                    ["traefik.enable"] = "true",
                    [$"traefik.http.routers.{tunnelLabel}.rule"]
                        = $"Host(`{ws.TunnelDna}.try.mosgarage.app`)",
                    [$"traefik.http.routers.{tunnelLabel}.entrypoints"] = "web",
                    [$"traefik.http.services.{tunnelLabel}.loadbalancer.server.port"] = "8080",
                    // code-server port
                    [$"traefik.http.routers.{tunnelLabel}-code.rule"]
                        = $"Host(`code.{ws.TunnelDna}.try.mosgarage.app`)",
                    [$"traefik.http.services.{tunnelLabel}-code.loadbalancer.server.port"] = "8080",
                },
            }, ct);

        var containerId = response.ID;
        await _docker.Containers.StartContainerAsync(containerId, null, ct);

        _log.LogInformation("Workspace {Name} started — container {Id}", ws.Name, containerId[..12]);
        return containerId;
    }

    // ── Stop workspace ───────────────────────────────────────────
    public async Task StopWorkspaceAsync(string containerId, CancellationToken ct = default)
    {
        _log.LogInformation("Stopping container {Id}", containerId[..12]);
        await _docker.Containers.StopContainerAsync(containerId,
            new ContainerStopParameters { WaitBeforeKillSeconds = 10 }, ct);
    }

    // ── Delete workspace ─────────────────────────────────────────
    public async Task DeleteWorkspaceAsync(string containerId, CancellationToken ct = default)
    {
        _log.LogInformation("Removing container {Id}", containerId[..12]);
        try
        {
            await _docker.Containers.RemoveContainerAsync(containerId,
                new ContainerRemoveParameters { Force = true, RemoveVolumes = false }, ct);
        }
        catch (DockerContainerNotFoundException)
        {
            _log.LogWarning("Container {Id} not found — already removed", containerId[..12]);
        }
    }

    // ── Get container stats ──────────────────────────────────────
    public async Task<ContainerInspectResponse?> InspectAsync(string containerId, CancellationToken ct = default)
    {
        try { return await _docker.Containers.InspectContainerAsync(containerId, ct); }
        catch (DockerContainerNotFoundException) { return null; }
    }

    // ── Pull image if not cached ──────────────────────────────────
    private async Task EnsureImageAsync(string image, CancellationToken ct)
    {
        var parts = image.Split(':');
        var name  = parts[0];
        var tag   = parts.Length > 1 ? parts[1] : "latest";

        var images = await _docker.Images.ListImagesAsync(
            new ImagesListParameters { Filters = new() { ["reference"] = new() { [image] = true } } }, ct);

        if (images.Count > 0) return;

        _log.LogInformation("Pulling image {Image}...", image);
        await _docker.Images.CreateImageAsync(
            new ImagesCreateParameters { FromImage = name, Tag = tag },
            null,
            new Progress<JSONMessage>(m =>
            {
                if (!string.IsNullOrEmpty(m.Status))
                    _log.LogDebug("[pull] {Status} {Progress}", m.Status, m.ProgressMessage);
            }), ct);
    }

    // ── Health check ─────────────────────────────────────────────
    public async Task<bool> IsHealthyAsync(CancellationToken ct = default)
    {
        try { await _docker.System.PingAsync(ct); return true; }
        catch { return false; }
    }

    public void Dispose() => _docker.Dispose();
}
