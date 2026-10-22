namespace Porida.Api.Features.Portfolios;

public class Portfolio
{
    public Guid Id { get; set; }

    public required string Name { get; set; }

    public DateTimeOffset CreatedAt { get; set; }

    public DateTimeOffset UpdatedAt { get; set; }
}