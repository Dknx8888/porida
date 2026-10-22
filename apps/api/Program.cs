using Porida.Api.Features.Health;
using Porida.Api.Features.Portfolios;
using Microsoft.EntityFrameworkCore;
using Porida.Api.Data;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();
builder.Services.AddValidation();


var connectionString = builder.Configuration.GetConnectionString("Porida")
    ?? throw new InvalidOperationException(
        "Connection string 'Porida' is not configured.");

builder.Services.AddDbContext<PoridaDbContext>(options =>
    options.UseNpgsql(connectionString));

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

// “When a GET request arrives at /api/portfolios (this is the endpoint), run this handler.”
app.MapGet("/api/portfolios", async (
    PoridaDbContext db,
    CancellationToken cancellationToken) =>
{
    var portfolios = await db.Portfolios
        .OrderByDescending(p => p.UpdatedAt)
        .Select(p => new PortfolioDto(
            p.Id,
            p.Name,
            p.CreatedAt,
            p.UpdatedAt))
        .ToListAsync(cancellationToken);

    return TypedResults.Ok(portfolios);
})
.WithName("GetPortfolios");

app.MapPost("/api/portfolios", async (
    CreatePortfolioRequest request,
    PoridaDbContext db,
    CancellationToken cancellationToken) =>
{
    var portfolio = new Portfolio
    {
        Name = request.Name.Trim()
    };

    db.Portfolios.Add(portfolio);
    await db.SaveChangesAsync(cancellationToken);

    var response = new PortfolioDto(
        portfolio.Id,
        portfolio.Name,
        portfolio.CreatedAt,
        portfolio.UpdatedAt);

    return TypedResults.Created(
        uri: (string?)null,
        value: response);
})
.WithName("CreatePortfolio");

// Health check endpoint
app.MapGet("/api/health", () =>
    TypedResults.Ok(new HealthDto("ok")))
.WithName("GetHealth");

app.Run();