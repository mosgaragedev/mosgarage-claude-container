// ============================================================
// Mosgarage.Server — Microsoft Entra ID Authentication
// Permissions: Tasks.ReadWrite · Group.Read.All · User.Read
// ============================================================

namespace Mosgarage.Server.Auth;

/// <summary>
/// Strongly-typed Entra ID / Azure AD configuration.
/// Bound from AzureAd section in appsettings.json + env vars.
/// </summary>
public sealed class EntraIdOptions
{
    public const string Section = "AzureAd";

    /// <summary>Azure AD tenant ID (Directory ID from Entra portal)</summary>
    public string TenantId     { get; set; } = "";

    /// <summary>Application (client) ID from the App Registration</summary>
    public string ClientId     { get; set; } = "";

    /// <summary>Client secret from the App Registration → Certificates & secrets</summary>
    public string ClientSecret { get; set; } = "";

    /// <summary>App ID URI — used for API scope validation. Usually api://{ClientId}</summary>
    public string Audience     { get; set; } = "";

    /// <summary>Authority URL — constructed automatically from TenantId</summary>
    public string Authority    => $"https://login.microsoftonline.com/{TenantId}";

    /// <summary>OAuth2 callback path (must match redirect URI in App Registration)</summary>
    public string CallbackPath { get; set; } = "/auth/signin-oidc";

    /// <summary>Sign-out callback path</summary>
    public string SignedOutCallbackPath { get; set; } = "/auth/signout-callback-oidc";

    /// <summary>Whether to allow personal Microsoft accounts (in addition to work/school)</summary>
    public bool AllowPersonalAccounts { get; set; } = false;

    // ── Microsoft Graph scopes requested during login ─────────────
    // These must match the API permissions granted in the App Registration.
    public static readonly string[] GraphScopes =
    [
        "User.Read",           // Read signed-in user's profile
        "Group.Read.All",      // Read all group memberships
        "Tasks.ReadWrite",     // Read and write To Do tasks (Microsoft To Do / Planner)
    ];

    // ── Validate ──────────────────────────────────────────────────
    public bool IsConfigured =>
        !string.IsNullOrEmpty(TenantId) &&
        !string.IsNullOrEmpty(ClientId) &&
        !string.IsNullOrEmpty(ClientSecret);
}

/// <summary>
/// Entra ID token claims — what we extract from the ID token.
/// </summary>
public sealed class EntraIdClaims
{
    public string  ObjectId    { get; init; } = "";
    public string  TenantId    { get; init; } = "";
    public string  Email       { get; init; } = "";
    public string  DisplayName { get; init; } = "";
    public string  GivenName   { get; init; } = "";
    public string  Surname     { get; init; } = "";
    public string  Username    { get; init; } = "";  // UPN (user@domain.com)
    public string[] Groups     { get; init; } = [];

    public static EntraIdClaims FromPrincipal(System.Security.Claims.ClaimsPrincipal principal)
    {
        string Claim(string type) =>
            principal.FindFirst(type)?.Value ?? "";

        return new EntraIdClaims
        {
            ObjectId    = Claim("oid")  != "" ? Claim("oid")  : Claim("http://schemas.microsoft.com/identity/claims/objectidentifier"),
            TenantId    = Claim("tid")  != "" ? Claim("tid")  : Claim("http://schemas.microsoft.com/identity/claims/tenantid"),
            Email       = Claim("email") != "" ? Claim("email") : Claim("preferred_username"),
            DisplayName = Claim("name"),
            GivenName   = Claim("given_name"),
            Surname     = Claim("family_name"),
            Username    = Claim("preferred_username"),
            Groups      = principal.FindAll("groups").Select(c => c.Value).ToArray(),
        };
    }
}
