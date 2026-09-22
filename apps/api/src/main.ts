import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module.js';
import { ConfigService } from '@nestjs/config';

async function bootstrap() {
    const app = await NestFactory.create(AppModule);

    const config = app.get(ConfigService);

    // Nest enables CORS through app.enableCors()
    app.enableCors({
        origin: config.getOrThrow<string>('WEB_ORIGIN'),
    });
  
    await app.listen(config.getOrThrow<number>('API_PORT'));
}
void bootstrap();
