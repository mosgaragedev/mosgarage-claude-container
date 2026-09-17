using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Mosgarage.Server.Auth;
using Mosgarage.Server.Data;
using Mosgarage.Server.Models;

namespace Mosgarage.Server.Services;

public sealed class AuthService(
    MosgarageDbContext db,
    MosgarageOptions   opts,
    EntraIdOptions     entraOpts,
    ILogger<AuthService> log)
{
    // ── Authenticate with email + password → JWT or null ─────────
    public async Task<string?> AuthenticateAsync(string email, string password, CancellationToken ct)
    {
        var user = await db.Users
            .FirstOrDefaultAsync(u => u.Email == email && u.IsActive, ct);

        if (user is null || !BCrypt.Net.BCrypt.Verify(password, user.PasswordHash))
        {
            log.LogWarning("Failed login for {Email}", email);
            return null;
        }

        user.LastLoginAt = DateTimeOffset.UtcNow;
        await db.SaveChangesAsync(ct);

        log.LogInformation("User {Email} authenticated (local)", email);
        return IssueJwt(user);
    }

    // ── Upsert a user arriving via Entra ID OIDC ─────────────────
    public async Task<User> UpsertEntraUserAsync(EntraIdClaims claims, CancellationToken ct)
    {
        var user = await db.Users.FirstOrDefaultAsync(u => u.Email == claims.Email, ct);

        if (user is null)
        {
            user = new User
            {
                Email        = claims.Email,
                Username     = claims.Username.Split('@')[0],
                PasswordHash = "",   // no local password for Entra users
                Role         = UserRole.Member,
                IsActive     = true,
            };
            db.Users.Add(user);
            log.LogInformation("New user provisioned from Entra ID: {Email}", claims.Email);
        }
        else
        {
            // Update profile from Entra on every login
            user.Username = claims.Username.Split('@')[0];
        }

        user.LastLoginAt = DateTimeOffset.UtcNow;
        user.Metadata["entra_oid"]    = claims.ObjectId;
        user.Metadata["entra_tenant"] = claims.TenantId;
        user.Metadata["display_name"] = claims.DisplayName;

        await db.SaveChangesAsync(ct);
        return user;
    }

    // ── Issue a mosgarage JWT ─────────────────────────────────────
    public string IssueJwt(User user)
    {
        var key     = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(opts.SecretKey));
        var creds   = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
        var expires = DateTime.UtcNow.AddHours(opts.JwtExpiryHours);

        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub,   user.Id.ToString()),
            new Claim(JwtRegisteredClaimNames.Email, user.Email),
            new Claim(JwtRegisteredClaimNames.Name,  user.Username),
            new Claim("role", user.Role.ToString().ToLower()),
            new Claim(JwtRegisteredClaimNames.Iat,
                DateTimeOffset.UtcNow.ToUnixTimeSeconds().ToString(),
                ClaimValueTypes.Integer64),
        };

        var token = new JwtSecurityToken(
            issuer:   opts.AccessUrl,
            audience: opts.AccessUrl,
            claims:   claims,
            expires:  expires,
            signingCredentials: creds);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    // ── Seed admin user on first boot ─────────────────────────────
    public async Task SeedAdminAsync()
    {
        if (await db.Users.AnyAsync()) return;

        var admin = new User
        {
            Email        = opts.AdminEmail,
            Username     = "admin",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(opts.AdminPassword),
            Role         = UserRole.Admin,
            IsActive     = true,
        };
        db.Users.Add(admin);
        await db.SaveChangesAsync();
        log.LogInformation("Admin user seeded: {Email}", opts.AdminEmail);
    }
}
