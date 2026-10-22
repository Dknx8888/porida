namespace Porida.Api.Features.Portfolios;

public record PortfolioDto(
    Guid Id,
    string Name,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt);
