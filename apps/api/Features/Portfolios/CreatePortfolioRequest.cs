using System.ComponentModel.DataAnnotations;

namespace Porida.Api.Features.Portfolios;

public class CreatePortfolioRequest
{
    [Required(ErrorMessage = "Portfolio name must not be empty.")]
    public string Name { get; init; } = string.Empty;
}