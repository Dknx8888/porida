import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module.js';
import { ConfigService } from '@nestjs/config';
import { ValidationPipe } from '@nestjs/common';

async function bootstrap() {
    const app = await NestFactory.create(AppModule);

    // Enable validation through Nest's ValidationPipe
    app.useGlobalPipes(
        new ValidationPipe({
            transform: true, // Pass transformed input class instances to your handlers
            whitelist: true, // Remove input properties that have no validation decorators
        }),
    );

    const config = app.get(ConfigService);

    // Nest enables CORS through app.enableCors()
    app.enableCors({
        origin: config.getOrThrow<string>('WEB_ORIGIN'),
    });
  
    await app.listen(config.getOrThrow<number>('API_PORT'));
}
void bootstrap();
