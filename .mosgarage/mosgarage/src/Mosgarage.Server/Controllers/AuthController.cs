using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;
using Mosgarage.Server.Auth;
using Mosgarage.Server.Data;
using Mosgarage.Server.Models;
using Mosgarage.Server.Services;

namespace Mosgarage.Server.Controllers;

[ApiController]
[Route("auth")]
public sealed class AuthController(
    EntraIdOptions entraOpts,
    MosgarageOptions mosgarageOpts,
    MosgarageDbContext db,
    AuthService authService,
    ILogger<AuthController> log)
    : ControllerBase
{
    // ── GET /auth/login ─── redirect to Entra ID / local login ────
    [HttpGet("login")]
    [AllowAnonymous]
    public IActionResult Login([FromQuery] string? returnUrl = "/")
    {
        if (entraOpts.IsConfigured)
        {
            // Redirect to Microsoft Entra ID OIDC flow
            return Challenge(new AuthenticationProperties
            {
                RedirectUri  = returnUrl ?? "/",
                Items        = { ["returnUrl"] = returnUrl },
            }, OpenIdConnectDefaults.AuthenticationScheme);
        }

        // Fall back to local credentials (dev mode)
        return Redirect($"/auth/local-login?returnUrl={Uri.EscapeDataString(returnUrl ?? "/")}");
    }

    // ── POST /auth/local-login ─── username + password → JWT ──────
    [HttpPost("local-login")]
    [AllowAnonymous]
    public async Task<IActionResult> LocalLogin(
        [FromBody] LocalLoginRequest req, CancellationToken ct)
    {
        var token = await authService.AuthenticateAsync(req.Email, req.Password, ct);
        if (token is null)
            return Unauthorized(new { error = "Invalid credentials" });

        return Ok(new { token, expires_in = mosgarageOpts.JwtExpiryHours * 3600 });
    }

    // ── GET /auth/signin-oidc ─── Entra callback → issue mosgarage JWT
    [HttpGet("signin-oidc")]
    [Authorize(AuthenticationSchemes = OpenIdConnectDefaults.AuthenticationScheme)]
    public async Task<IActionResult> EntraCallback(CancellationToken ct)
    {
        var entClaims = EntraIdClaims.FromPrincipal(User);

        log.LogInformation("Entra ID login: {Email} (oid={ObjectId})",
            entClaims.Email, entClaims.ObjectId);

        // Upsert user into mosgarage database
        var user = await authService.UpsertEntraUserAsync(entClaims, ct);

        // Issue mosgarage JWT (short-lived, API-usable)
        var jwt = authService.IssueJwt(user);

        // Redirect to SPA with token in fragment (or set cookie)
        return Redirect($"/?token={Uri.EscapeDataString(jwt)}#auth");
    }

    // ── GET /auth/logout ──────────────────────────────────────────
    [HttpGet("logout")]
    public IActionResult Logout()
    {
        if (entraOpts.IsConfigured)
        {
            return SignOut(new AuthenticationProperties { RedirectUri = "/" },
                OpenIdConnectDefaults.AuthenticationScheme,
                "Cookies");
        }
        return Redirect("/");
    }

    // ── GET /auth/me ─── current user info ────────────────────────
    [HttpGet("me")]
    [Authorize]
    public async Task<IActionResult> Me(CancellationToken ct)
    {
        var userId = Guid.Parse(User.FindFirst("sub")?.Value ?? Guid.Empty.ToString());
        var user   = await db.Users.FindAsync([userId], ct);
        if (user is null) return NotFound();

        return Ok(new
        {
            id           = user.Id,
            email        = user.Email,
            username     = user.Username,
            role         = user.Role.ToString().ToLower(),
            last_login   = user.LastLoginAt,
            entra_linked = entraOpts.IsConfigured,
            graph_scopes = entraOpts.IsConfigured ? EntraIdOptions.GraphScopes : null,
        });
    }

    // ── GET /auth/config ─── tells the SPA what auth method is active
    [HttpGet("config")]
    [AllowAnonymous]
    public IActionResult Config() => Ok(new
    {
        entra_enabled      = entraOpts.IsConfigured,
        tenant_id          = entraOpts.IsConfigured ? entraOpts.TenantId : null,
        client_id          = entraOpts.IsConfigured ? entraOpts.ClientId : null,
        scopes             = entraOpts.IsConfigured ? EntraIdOptions.GraphScopes : null,
        login_url          = "/auth/login",
        logout_url         = "/auth/logout",
    });
}

public record LocalLoginRequest(string Email, string Password);
