import { ApolloDriver, type ApolloDriverConfig } from '@nestjs/apollo';
import { GraphQLModule } from '@nestjs/graphql';
import { Module } from '@nestjs/common';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { HealthModule } from './health/health.module.js';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { environmentSchema } from './config/environment.schema.js';
import { TypeOrmModule } from '@nestjs/typeorm';
import type { TypeOrmModuleOptions } from '@nestjs/typeorm';

@Module({
    imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          validationSchema: environmentSchema,
        }),

        TypeOrmModule.forRootAsync({
          inject: [ConfigService],
          useFactory: (config: ConfigService): TypeOrmModuleOptions => ({
            type: 'postgres',
            host: config.getOrThrow<string>('DATABASE_HOST'),
            port: config.getOrThrow<number>('DATABASE_PORT'),
            username: config.getOrThrow<string>('DATABASE_USER'),
            password: config.getOrThrow<string>('DATABASE_PASSWORD'),
            database: config.getOrThrow<string>('DATABASE_NAME'),
        
            autoLoadEntities: true,
            synchronize: false,
            migrationsRun: false,
          }),
        }),
        
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
