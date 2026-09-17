// ╔══════════════════════════════════════════════════════════════════╗
// ║  Mosgarage.Server — Control Plane                                ║
// ║  .NET 8 · SignalR · EF Core · PostgreSQL · JWT                  ║
// ║  Microsoft Entra ID OIDC (Tasks.ReadWrite · Group.Read.All ·    ║
// ║  User.Read) · Docker provisioner · Unix socket IPC              ║
// ╚══════════════════════════════════════════════════════════════════╝

using System.Text;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Identity.Web;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using Mosgarage.Server.Auth;
using Mosgarage.Server.Data;
using Mosgarage.Server.Hubs;
using Mosgarage.Server.Middleware;
using Mosgarage.Server.Models;
using Mosgarage.Server.Services;
using Serilog;

Log.Logger = new LoggerConfiguration()
    .WriteTo.Console(outputTemplate:
        "[{Timestamp:HH:mm:ss} {Level:u3}] {SourceContext} {Message:lj}{NewLine}{Exception}")
    .CreateBootstrapLogger();

try
{
    var builder = WebApplication.CreateBuilder(args);

    // ── Serilog ──────────────────────────────────────────────────
    builder.Host.UseSerilog((ctx, services, cfg) => cfg
        .ReadFrom.Configuration(ctx.Configuration)
        .ReadFrom.Services(services)
        .Enrich.FromLogContext()
        .Enrich.WithProperty("App", "mosgarage")
        .WriteTo.Console(outputTemplate:
            "[{Timestamp:HH:mm:ss} {Level:u3}] {SourceContext} {Message:lj}{NewLine}{Exception}")
        .WriteTo.File("/var/log/mosgarage/server-.log",
            rollingInterval: RollingInterval.Day, retainedFileCountLimit: 7));

    var cfg        = builder.Configuration;
    var secretKey  = cfg["MOSGARAGE_SECRET_KEY"]   ?? throw new InvalidOperationException("MOSGARAGE_SECRET_KEY not set");
    var pgConn     = cfg["MOSGARAGE_PG_CONNECTION"] ?? throw new InvalidOperationException("MOSGARAGE_PG_CONNECTION not set");
    var accessUrl  = cfg["MOSGARAGE_ACCESS_URL"]    ?? "http://localhost:7070";

    // ── Entra ID options ─────────────────────────────────────────
    var entraOpts = new EntraIdOptions();
    cfg.GetSection(EntraIdOptions.Section).Bind(entraOpts);
    // Also accept flat env vars: AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_CLIENT_SECRET
    if (string.IsNullOrEmpty(entraOpts.ClientId))
        entraOpts.ClientId = cfg["AZURE_CLIENT_ID"] ?? cfg["ENTRA_CLIENT_ID"] ?? "";
    if (string.IsNullOrEmpty(entraOpts.TenantId))
        entraOpts.TenantId = cfg["AZURE_TENANT_ID"] ?? cfg["ENTRA_TENANT_ID"] ?? "";
    if (string.IsNullOrEmpty(entraOpts.ClientSecret))
        entraOpts.ClientSecret = cfg["AZURE_CLIENT_SECRET"] ?? cfg["ENTRA_CLIENT_SECRET"] ?? "";
    if (string.IsNullOrEmpty(entraOpts.Audience))
        entraOpts.Audience = cfg["ENTRA_AUDIENCE"] ?? $"api://{entraOpts.ClientId}";
    builder.Services.AddSingleton(entraOpts);

    // ── Database ─────────────────────────────────────────────────
    builder.Services.AddDbContext<MosgarageDbContext>(opts =>
        opts.UseNpgsql(pgConn,
            n => n.EnableRetryOnFailure(5, TimeSpan.FromSeconds(10), null)
                  .CommandTimeout(60))
            .UseSnakeCaseNamingConvention());

    // ── Authentication pipeline ───────────────────────────────────
    var jwtKey = Encoding.UTF8.GetBytes(secretKey);
    var authBuilder = builder.Services
        .AddAuthentication(opts =>
        {
            // Default for API: JWT; Default for browser: Cookie + OIDC
            opts.DefaultScheme          = "SmartScheme";
            opts.DefaultChallengeScheme = entraOpts.IsConfigured
                ? OpenIdConnectDefaults.AuthenticationScheme
                : JwtBearerDefaults.AuthenticationScheme;
        })
        // ── JWT (API clients and workspace agents) ────────────────
        .AddJwtBearer(JwtBearerDefaults.AuthenticationScheme, opts =>
        {
            opts.TokenValidationParameters = new TokenValidationParameters
            {
                ValidateIssuerSigningKey = true,
                IssuerSigningKey         = new SymmetricSecurityKey(jwtKey),
                ValidateIssuer           = false,
                ValidateAudience         = false,
                ClockSkew                = TimeSpan.Zero,
            };
            // Allow JWT via query-string for SignalR
            opts.Events = new JwtBearerEvents
            {
                OnMessageReceived = ctx =>
                {
                    var token = ctx.Request.Query["access_token"];
                    if (!string.IsNullOrEmpty(token) &&
                        ctx.HttpContext.Request.Path.StartsWithSegments("/hubs"))
                        ctx.Token = token;
                    return Task.CompletedTask;
                }
            };
        })
        // ── Cookie (browser sessions) ─────────────────────────────
        .AddCookie("Cookies", opts =>
        {
            opts.Cookie.Name     = "mosgarage.session";
            opts.Cookie.HttpOnly = true;
            opts.Cookie.SameSite = SameSiteMode.Lax;
            opts.ExpireTimeSpan  = TimeSpan.FromHours(24);
            opts.SlidingExpiration = true;
            opts.LoginPath  = "/auth/login";
            opts.LogoutPath = "/auth/logout";
        });

    // ── Microsoft Entra ID OIDC (conditional — only if configured) ─
    if (entraOpts.IsConfigured)
    {
        Log.Information("Microsoft Entra ID configured — tenant={TenantId} client={ClientId}",
            entraOpts.TenantId, entraOpts.ClientId);

        authBuilder.AddOpenIdConnect(OpenIdConnectDefaults.AuthenticationScheme, opts =>
        {
            opts.Authority            = entraOpts.Authority;
            opts.ClientId             = entraOpts.ClientId;
            opts.ClientSecret         = entraOpts.ClientSecret;
            opts.CallbackPath         = entraOpts.CallbackPath;
            opts.SignedOutCallbackPath = entraOpts.SignedOutCallbackPath;
            opts.ResponseType         = "code";
            opts.SaveTokens           = true;
            opts.GetClaimsFromUserInfoEndpoint = true;
            opts.SignInScheme          = "Cookies";

            // ── Request the three required Graph scopes ───────────
            opts.Scope.Clear();
            opts.Scope.Add("openid");
            opts.Scope.Add("profile");
            opts.Scope.Add("email");
            opts.Scope.Add("offline_access");
            foreach (var scope in EntraIdOptions.GraphScopes)
                opts.Scope.Add(scope);

            // ── Token validation ──────────────────────────────────
            opts.TokenValidationParameters = new TokenValidationParameters
            {
                ValidateIssuer      = true,
                ValidIssuers        = new[]
                {
                    // Single-tenant
                    $"https://login.microsoftonline.com/{entraOpts.TenantId}/v2.0",
                    // Multi-tenant (common)
                    "https://login.microsoftonline.com/common/v2.0",
                },
                NameClaimType = "preferred_username",
                RoleClaimType = "roles",
            };

            // ── Events ───────────────────────────────────────────
            opts.Events = new OpenIdConnectEvents
            {
                OnTokenValidated = async ctx =>
                {
                    var claims = EntraIdClaims.FromPrincipal(ctx.Principal!);
                    Log.Information("Entra ID token validated for {Email}", claims.Email);

                    // Upsert user in database
                    var authSvc = ctx.HttpContext.RequestServices
                        .GetRequiredService<AuthService>();
                    await authSvc.UpsertEntraUserAsync(claims, ctx.HttpContext.RequestAborted);
                },
                OnAuthenticationFailed = ctx =>
                {
                    Log.Warning("Entra ID authentication failed: {Error}", ctx.Exception.Message);
                    ctx.Response.Redirect($"/auth/error?message={Uri.EscapeDataString(ctx.Exception.Message)}");
                    ctx.HandleResponse();
                    return Task.CompletedTask;
                },
                OnRemoteFailure = ctx =>
                {
                    Log.Warning("Entra ID remote failure: {Error}", ctx.Failure?.Message);
                    ctx.Response.Redirect("/auth/login");
                    ctx.HandleResponse();
                    return Task.CompletedTask;
                },
            };
        });
    }
    else
    {
        Log.Warning("Microsoft Entra ID NOT configured — using local auth only. " +
                    "Set ENTRA_CLIENT_ID, ENTRA_TENANT_ID, ENTRA_CLIENT_SECRET to enable.");
    }

    // Smart scheme: JWT for API (Authorization header), Cookie for browser
    builder.Services.AddSingleton<Microsoft.AspNetCore.Authentication.IAuthenticationSchemeProvider,
        SmartAuthSchemeProvider>();

    builder.Services.AddAuthorization(opts =>
    {
        opts.AddPolicy("Admin", p => p.RequireClaim("role", "admin"));
        opts.AddPolicy("Member", p => p.RequireAuthenticatedUser());
    });

    // ── SignalR ──────────────────────────────────────────────────
    builder.Services.AddSignalR(opts =>
    {
        opts.EnableDetailedErrors      = builder.Environment.IsDevelopment();
        opts.MaximumReceiveMessageSize = 1024 * 1024;
        opts.KeepAliveInterval         = TimeSpan.FromSeconds(30);
        opts.ClientTimeoutInterval     = TimeSpan.FromSeconds(90);
    });

    // ── Health checks ─────────────────────────────────────────────
    builder.Services.AddHealthChecks()
        .AddNpgSql(pgConn,      name: "postgres",     tags: ["db", "ready"])
        .AddCheck<DockerHealthCheck>("docker",         tags: ["provisioner"])
        .AddCheck<SocketHealthCheck>("unix-socket",    tags: ["ipc"])
        .AddCheck<SshHealthCheck>("ssh-server",        tags: ["ssh"]);

    // ── CORS ──────────────────────────────────────────────────────
    builder.Services.AddCors(opts => opts.AddDefaultPolicy(p =>
        p.SetIsOriginAllowed(_ => true).AllowAnyMethod().AllowAnyHeader().AllowCredentials()));

    // ── Controllers + Swagger ─────────────────────────────────────
    builder.Services.AddControllers();
    builder.Services.AddEndpointsApiExplorer();
    builder.Services.AddSwaggerGen(o =>
    {
        o.SwaggerDoc("v1", new OpenApiInfo { Title = "Mosgarage API", Version = "v1" });
        o.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
        {
            Type = SecuritySchemeType.Http, Scheme = "bearer", BearerFormat = "JWT",
            Description = "JWT token from /auth/local-login or /auth/signin-oidc",
        });
        if (entraOpts.IsConfigured)
        {
            o.AddSecurityDefinition("EntraId", new OpenApiSecurityScheme
            {
                Type  = SecuritySchemeType.OAuth2,
                Flows = new OpenApiOAuthFlows
                {
                    AuthorizationCode = new OpenApiOAuthFlow
                    {
                        AuthorizationUrl = new Uri($"{entraOpts.Authority}/oauth2/v2.0/authorize"),
                        TokenUrl         = new Uri($"{entraOpts.Authority}/oauth2/v2.0/token"),
                        Scopes = EntraIdOptions.GraphScopes.ToDictionary(s => s, s => s),
                    }
                }
            });
        }
    });

    // ── App services ──────────────────────────────────────────────
    builder.Services.Configure<MosgarageOptions>(cfg);
    builder.Services.AddSingleton<MosgarageOptions>(sp =>
    {
        var o = new MosgarageOptions(); cfg.Bind(o); return o;
    });
    builder.Services.AddSingleton<TunnelService>();
    builder.Services.AddSingleton<UnixSocketService>();
    builder.Services.AddSingleton<DockerProvisionerService>();
    builder.Services.AddScoped<WorkspaceService>();
    builder.Services.AddScoped<AuthService>();
    builder.Services.AddScoped<TemplateService>();
    builder.Services.AddHostedService<GitSyncBackgroundService>();
    builder.Services.AddHostedService<WorkspaceGarbageCollector>();
    builder.Services.AddHostedService<AgentSocketListener>();
    builder.Services.AddHttpContextAccessor();
    builder.Services.AddResponseCompression();
    builder.Services.AddMemoryCache();

    var app = builder.Build();

    // ── Auto-migrate ──────────────────────────────────────────────
    using (var scope = app.Services.CreateScope())
    {
        var db2 = scope.ServiceProvider.GetRequiredService<MosgarageDbContext>();
        await db2.Database.MigrateAsync();
        var authSvc = scope.ServiceProvider.GetRequiredService<AuthService>();
        await authSvc.SeedAdminAsync();
    }

    // ── Pipeline ──────────────────────────────────────────────────
    app.UseSerilogRequestLogging(o => o.MessageTemplate =
        "HTTP {RequestMethod} {RequestPath} → {StatusCode} ({Elapsed:0}ms)");

    if (app.Environment.IsDevelopment())
    {
        app.UseSwagger();
        app.UseSwaggerUI(o =>
        {
            o.SwaggerEndpoint("/swagger/v1/swagger.json", "Mosgarage API v1");
            if (entraOpts.IsConfigured)
            {
                o.OAuthClientId(entraOpts.ClientId);
                o.OAuthUsePkce();
            }
        });
    }

    app.UseResponseCompression();
    app.UseCors();
    app.UseDefaultFiles();
    app.UseStaticFiles();
    app.UseRouting();
    app.UseAuthentication();
    app.UseAuthorization();

    app.MapControllers();
    app.MapHub<WorkspaceHub>("/hubs/workspace").RequireAuthorization();
    app.MapHub<AgentHub>("/hubs/agent");
    app.MapHealthChecks("/healthz");
    app.MapHealthChecks("/healthz/ready", new() { Predicate = c => c.Tags.Contains("ready") });
    app.MapFallbackToFile("index.html");

    Log.Information("""
    ╔══════════════════════════════════════════════════════╗
    ║  mosgarage control plane ready                       ║
    ╠══════════════════════════════════════════════════════╣
    ║  HTTP     → {Url}
    ║  Auth     → {Auth}
    ║  SSH      → port 2222
    ║  Docs     → {Url}/swagger
    ╚══════════════════════════════════════════════════════╝
    """, accessUrl, entraOpts.IsConfigured ? "Microsoft Entra ID + JWT" : "Local JWT only",
         accessUrl);

    await app.RunAsync();
    return 0;
}
catch (Exception ex) when (ex is not HostAbortedException)
{
    Log.Fatal(ex, "mosgarage crashed on startup");
    return 1;
}
finally { Log.CloseAndFlush(); }

// ── Smart auth scheme: JWT for API calls, Cookie for browser ──────
public sealed class SmartAuthSchemeProvider(
    Microsoft.Extensions.Options.IOptions<Microsoft.AspNetCore.Authentication.AuthenticationOptions> options)
    : Microsoft.AspNetCore.Authentication.AuthenticationSchemeProvider(options)
{
    public override async Task<Microsoft.AspNetCore.Authentication.AuthenticationScheme?> GetDefaultAuthenticateSchemeAsync()
        => await GetSchemeAsync(JwtBearerDefaults.AuthenticationScheme);
}
