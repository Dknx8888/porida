import { Injectable } from "@nestjs/common";
import { InjectRepository } from '@nestjs/typeorm';
import type { Repository } from 'typeorm';
import { Portfolio } from './portfolio.entity.js';

@Injectable()
export class PortfoliosService {
    constructor(
        @InjectRepository(Portfolio)
        private readonly portfolioRepository: Repository<Portfolio>
    ) { }

    findAll(): Promise<Portfolio[]> {
        return this.portfolioRepository.find({
            order: {
                updatedAt: 'DESC',
            }
        }) 
    }

    create(name: string): Promise<Portfolio> {
        const portfolio = this.portfolioRepository.create({ name })
        return this.portfolioRepository.save(portfolio)
    }
}