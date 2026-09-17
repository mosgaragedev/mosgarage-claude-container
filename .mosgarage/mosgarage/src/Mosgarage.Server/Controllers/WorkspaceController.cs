using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Mosgarage.Server.Models;
using Mosgarage.Server.Services;

namespace Mosgarage.Server.Controllers;

[ApiController]
[Route("api/v1/workspaces")]
[Authorize]
[Produces("application/json")]
public sealed class WorkspaceController(
    WorkspaceService workspaceService,
    ILogger<WorkspaceController> log)
    : ControllerBase
{
    // ── GET /api/v1/workspaces ─────────────────────────────────────
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct)
    {
        var userId = GetUserId();
        var items  = await workspaceService.ListAsync(userId, ct);
        return Ok(new { workspaces = items });
    }

    // ── GET /api/v1/workspaces/{id} ───────────────────────────────
    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Get(Guid id, CancellationToken ct)
    {
        var ws = await workspaceService.GetAsync(id, GetUserId(), ct);
        return ws is null ? NotFound() : Ok(ws);
    }

    // ── POST /api/v1/workspaces ────────────────────────────────────
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateWorkspaceRequest req, CancellationToken ct)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);

        var ws = await workspaceService.CreateAsync(GetUserId(), req, ct);
        log.LogInformation("Workspace created {Name} by user {UserId}", ws.Name, GetUserId());
        return CreatedAtAction(nameof(Get), new { id = ws.Id }, ws);
    }

    // ── PUT /api/v1/workspaces/{id}/start ─────────────────────────
    [HttpPut("{id:guid}/start")]
    public async Task<IActionResult> Start(Guid id, CancellationToken ct)
    {
        var result = await workspaceService.StartAsync(id, GetUserId(), ct);
        return result.Success ? Ok(result) : BadRequest(result);
    }

    // ── PUT /api/v1/workspaces/{id}/stop ──────────────────────────
    [HttpPut("{id:guid}/stop")]
    public async Task<IActionResult> Stop(Guid id, CancellationToken ct)
    {
        var result = await workspaceService.StopAsync(id, GetUserId(), ct);
        return result.Success ? Ok(result) : BadRequest(result);
    }

    // ── DELETE /api/v1/workspaces/{id} ────────────────────────────
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id, CancellationToken ct)
    {
        await workspaceService.DeleteAsync(id, GetUserId(), ct);
        return NoContent();
    }

    // ── GET /api/v1/workspaces/{id}/builds ───────────────────────
    [HttpGet("{id:guid}/builds")]
    public async Task<IActionResult> Builds(Guid id, CancellationToken ct)
    {
        var builds = await workspaceService.GetBuildsAsync(id, GetUserId(), ct);
        return Ok(new { builds });
    }

    // ── GET /api/v1/workspaces/{id}/tunnel ───────────────────────
    [HttpGet("{id:guid}/tunnel")]
    public async Task<IActionResult> TunnelUrl(Guid id, CancellationToken ct)
    {
        var ws = await workspaceService.GetAsync(id, GetUserId(), ct);
        if (ws is null) return NotFound();
        return Ok(new
        {
            workspace_url  = $"https://{ws.TunnelDna}.try.mosgarage.app",
            code_server_url = $"https://code.{ws.TunnelDna}.try.mosgarage.app",
            agent_status   = ws.Status.ToString().ToLower(),
        });
    }

    private Guid GetUserId() =>
        Guid.Parse(User.FindFirst("sub")?.Value
            ?? throw new UnauthorizedAccessException("No sub claim"));
}

// ── Request DTOs ──────────────────────────────────────────────────
public record CreateWorkspaceRequest(
    string Name,
    Guid   TemplateId,
    bool   AutoStop        = true,
    int    AutoStopMinutes = 120
);

public record WorkspaceActionResult(bool Success, string Message, Guid WorkspaceId);
