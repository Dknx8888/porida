import { Resolver, Query } from "@nestjs/graphql";
import { PortfolioType } from "./portfolio.type.js";
import { PortfoliosService } from "./portfolios.service.js";

@Resolver(() => PortfolioType)
export class PortfoliosResolver {
    constructor(
        private readonly portfoliosService: PortfoliosService
    ) { }

    @Query(() => [PortfolioType], { name: 'portfolios' })
    getPortfolios(): Promise<PortfolioType[]> {
        return this.portfoliosService.findAll()
    }
}