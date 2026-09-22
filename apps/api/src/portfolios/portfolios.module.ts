import { Module } from "@nestjs/common";
import { TypeOrmModule } from '@nestjs/typeorm';
import { Portfolio } from './portfolio.entity.js';
import { PortfoliosService } from "./portfolios.service.js";
import { PortfoliosResolver } from "./portfolios.resolver.js";

@Module({
    // Other modules, including TypeOrmModule.forFeature(...) belong here
    imports: [
        TypeOrmModule.forFeature([Portfolio])
    ], 
    // Services and other dependencies Nest manages belong here
    providers: [
        PortfoliosService,
        PortfoliosResolver
    ]
})
export class PortfoliosModule {
    
}