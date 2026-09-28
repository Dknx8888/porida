import { Resolver, Query, Mutation, Args } from "@nestjs/graphql";
import { PortfolioType } from "./portfolio.type.js";
import { PortfoliosService } from "./portfolios.service.js";
import { CreatePortfolioInput } from './portfolio.inputs.js';

@Resolver(() => PortfolioType)
export class PortfoliosResolver {
    constructor(
        private readonly portfoliosService: PortfoliosService
    ) { }

    @Query(() => [PortfolioType], { name: 'portfolios' })
    getPortfolios(): Promise<PortfolioType[]> {
        return this.portfoliosService.findAll()
    }

    @Mutation(() => PortfolioType, { name: 'createPortfolio' })
    createPortfolio(
        @Args('input') input: CreatePortfolioInput
    ): Promise<PortfolioType> {
        return this.portfoliosService.create(input.name)
    }
}