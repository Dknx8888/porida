using Microsoft.EntityFrameworkCore;
using Porida.Api.Features.Portfolios;

namespace Porida.Api.Data;

public class PoridaDbContext : DbContext
{
    public PoridaDbContext(DbContextOptions<PoridaDbContext> options) : base(options) { }

    public DbSet<Portfolio> Portfolios => Set<Portfolio>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        var portfolio = modelBuilder.Entity<Portfolio>();

        portfolio.ToTable("portfolio", "public");

        portfolio.HasKey(p => p.Id)
            .HasName("pk_portfolio");

        portfolio.Property(p => p.Id)
            .HasColumnName("id")
            .HasColumnType("uuid")
            .HasDefaultValueSql("gen_random_uuid()");

        portfolio.Property(p => p.Name)
            .HasColumnName("name")
            .HasColumnType("text")
            .IsRequired();

        portfolio.Property(p => p.CreatedAt)
            .HasColumnName("created_at")
            .HasColumnType("timestamp with time zone")
            .HasDefaultValueSql("CURRENT_TIMESTAMP");

        portfolio.Property(p => p.UpdatedAt)
            .HasColumnName("updated_at")
            .HasColumnType("timestamp with time zone")
            .HasDefaultValueSql("CURRENT_TIMESTAMP");
    }
}