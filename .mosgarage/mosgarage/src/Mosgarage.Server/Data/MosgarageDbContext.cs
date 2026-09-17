using Microsoft.EntityFrameworkCore;
using Mosgarage.Server.Models;

namespace Mosgarage.Server.Data;

public sealed class MosgarageDbContext(DbContextOptions<MosgarageDbContext> options)
    : DbContext(options)
{
    public DbSet<User>              Users              => Set<User>();
    public DbSet<ApiKey>            ApiKeys            => Set<ApiKey>();
    public DbSet<Workspace>         Workspaces         => Set<Workspace>();
    public DbSet<WorkspaceBuild>    WorkspaceBuilds    => Set<WorkspaceBuild>();
    public DbSet<WorkspaceTemplate> WorkspaceTemplates => Set<WorkspaceTemplate>();

    protected override void OnModelCreating(ModelBuilder model)
    {
        base.OnModelCreating(model);

        // ── User ──────────────────────────────────────────────
        model.Entity<User>(e =>
        {
            e.HasKey(u => u.Id);
            e.HasIndex(u => u.Email).IsUnique();
            e.HasIndex(u => u.Username).IsUnique();
            e.Property(u => u.Role).HasConversion<string>();
            e.Property(u => u.Metadata).HasColumnType("jsonb")
             .HasDefaultValueSql("'{}'::jsonb")
             .HasConversion(
                 v => System.Text.Json.JsonSerializer.Serialize(v, default(System.Text.Json.JsonSerializerOptions)),
                 v => System.Text.Json.JsonSerializer.Deserialize<Dictionary<string, string>>(v, default(System.Text.Json.JsonSerializerOptions))!);
        });

        // ── ApiKey ────────────────────────────────────────────
        model.Entity<ApiKey>(e =>
        {
            e.HasKey(k => k.Id);
            e.HasIndex(k => k.HashedKey).IsUnique();
            e.HasOne(k => k.User)
             .WithMany(u => u.ApiKeys)
             .HasForeignKey(k => k.UserId)
             .OnDelete(DeleteBehavior.Cascade);
        });

        // ── WorkspaceTemplate ─────────────────────────────────
        model.Entity<WorkspaceTemplate>(e =>
        {
            e.HasKey(t => t.Id);
            e.HasIndex(t => t.Name).IsUnique();
        });

        // ── Workspace ─────────────────────────────────────────
        model.Entity<Workspace>(e =>
        {
            e.HasKey(w => w.Id);
            e.HasIndex(w => w.TunnelDna).IsUnique();
            e.HasIndex(w => new { w.OwnerId, w.Name }).IsUnique();
            e.Property(w => w.Status).HasConversion<string>();
            e.Property(w => w.Metadata)
             .HasColumnType("jsonb")
             .HasDefaultValueSql("'{}'::jsonb")
             .HasConversion(
                 v => System.Text.Json.JsonSerializer.Serialize(v, default(System.Text.Json.JsonSerializerOptions)),
                 v => System.Text.Json.JsonSerializer.Deserialize<Dictionary<string, string>>(v, default(System.Text.Json.JsonSerializerOptions))!);

            e.HasOne(w => w.Owner)
             .WithMany(u => u.Workspaces)
             .HasForeignKey(w => w.OwnerId)
             .OnDelete(DeleteBehavior.Restrict);

            e.HasOne(w => w.Template)
             .WithMany(t => t.Workspaces)
             .HasForeignKey(w => w.TemplateId)
             .OnDelete(DeleteBehavior.Restrict);

            // Soft-delete filter
            e.HasQueryFilter(w => w.DeletedAt == null);
        });

        // ── WorkspaceBuild ────────────────────────────────────
        model.Entity<WorkspaceBuild>(e =>
        {
            e.HasKey(b => b.Id);
            e.Property(b => b.Reason).HasConversion<string>();
            e.Property(b => b.Status).HasConversion<string>();
            e.HasOne(b => b.Workspace)
             .WithMany(w => w.Builds)
             .HasForeignKey(b => b.WorkspaceId)
             .OnDelete(DeleteBehavior.Cascade);
        });

        // ── Seed default template ─────────────────────────────
        model.Entity<WorkspaceTemplate>().HasData(new WorkspaceTemplate
        {
            Id          = new Guid("00000000-0000-0000-0000-000000000001"),
            Name        = "node-workspace",
            DisplayName = "Node.js Workspace",
            Description = "Full-stack Node.js with code-server, PM2, and mosgarage agent",
            Icon        = "⬡",
            DockerImage = "docker.io/mosgarage/workspace:latest",
            YamlContent = "# See templates/node-workspace.yaml",
            Version     = 1,
            IsActive    = true,
            CreatedAt   = DateTimeOffset.UnixEpoch,
            UpdatedAt   = DateTimeOffset.UnixEpoch,
        });
    }
}
