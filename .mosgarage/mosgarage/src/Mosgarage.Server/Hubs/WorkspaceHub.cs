using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Mosgarage.Server.Services;

namespace Mosgarage.Server.Hubs;

/// <summary>
/// SignalR hub — pushes real-time workspace status, build logs,
/// and agent metrics to the browser UI.
/// </summary>
[Authorize]
public sealed class WorkspaceHub(
    WorkspaceService workspaceService,
    ILogger<WorkspaceHub> log)
    : Hub
{
    public override async Task OnConnectedAsync()
    {
        var userId = Context.UserIdentifier;
        log.LogInformation("[hub:workspace] Client connected {ConnectionId} user={UserId}",
            Context.ConnectionId, userId);

        // Add to personal group
        await Groups.AddToGroupAsync(Context.ConnectionId, $"user:{userId}");
        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        log.LogInformation("[hub:workspace] Client disconnected {ConnectionId}", Context.ConnectionId);
        await base.OnDisconnectedAsync(exception);
    }

    // ── Client → Server ───────────────────────────────────────────
    public async Task SubscribeToWorkspace(Guid workspaceId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, $"ws:{workspaceId}");
        log.LogDebug("[hub] {ConnectionId} subscribed to workspace {Id}", Context.ConnectionId, workspaceId);
    }

    public async Task UnsubscribeFromWorkspace(Guid workspaceId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, $"ws:{workspaceId}");
    }

    // ── Server → Client events (called from services) ─────────────
    // These methods are called by services to push updates:
    //
    //  Clients.Group($"ws:{id}").SendAsync("WorkspaceUpdated", dto)
    //  Clients.Group($"ws:{id}").SendAsync("BuildLog", line)
    //  Clients.Group($"ws:{id}").SendAsync("AgentMetrics", metrics)
    //  Clients.Group($"user:{uid}").SendAsync("WorkspaceList", dtos)
}

/// <summary>
/// SignalR hub for agent → server real-time messaging (alternative to socket for HTTP/2 envs).
/// Agents connect with their agentToken as the identifier.
/// </summary>
public sealed class AgentHub(
    UnixSocketService socketService,
    ILogger<AgentHub> log)
    : Hub
{
    public override async Task OnConnectedAsync()
    {
        log.LogInformation("[hub:agent] Agent connected {ConnectionId}", Context.ConnectionId);
        await base.OnConnectedAsync();
    }

    public async Task SendHeartbeat(object payload)
    {
        log.LogDebug("[hub:agent] Heartbeat from {ConnectionId}", Context.ConnectionId);
        // Forward to socket service for processing
    }
}
