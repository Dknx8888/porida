import { ApolloDriver, type ApolloDriverConfig } from '@nestjs/apollo';
import { GraphQLModule } from '@nestjs/graphql';
import { Module } from '@nestjs/common';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { HealthModule } from './health/health.module.js';

@Module({
    imports: [
        // Connects GraphQL to NestJS
        // .forRoot means one app wide GraphQL module
        // ApolloDriverConfig checks that this configuration object follows Apollo’s configuration rules.
        GraphQLModule.forRoot<ApolloDriverConfig>({ 
            driver: ApolloDriver,
            autoSchemaFile: true, // Code-first GraphQL
            sortSchema: true,
        }),
        HealthModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
