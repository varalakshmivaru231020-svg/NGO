import { NestFactory } from '@nestjs/core';
import { ValidationPipe, VersioningType } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import helmet from 'helmet';
import cookieParser from 'cookie-parser';
import { json, urlencoded } from 'express';
import { AppModule } from './app.module';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { TransformInterceptor } from './common/interceptors/transform.interceptor';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    logger: ['error', 'warn', 'log'],
    bodyParser: false, // replaced below with a higher limit (base64 photos)
  });

  const configService = app.get(ConfigService);

  app.use(helmet());
  app.use(cookieParser());
  // Allow base64 images (avatars / student photos) and short activity
  // videos (up to ~20MB original, ~27MB once base64-encoded) in JSON bodies.
  app.use(json({ limit: '30mb' }));
  app.use(urlencoded({ extended: true, limit: '30mb' }));

  // FRONTEND_URL may be a comma-separated list of allowed origins. Local dev
  // origins (Flutter web on :3007, admin on :3000) are always allowed.
  const configuredOrigins = configService
    .get('FRONTEND_URL', 'http://localhost:3000')
    .split(',')
    .map((o: string) => o.trim())
    .filter(Boolean);
  const allowedOrigins = Array.from(new Set([
    ...configuredOrigins,
    'http://localhost:3000',
    'http://localhost:3007',
  ]));
  app.enableCors({
    origin: allowedOrigins,
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  });

  app.enableVersioning({ type: VersioningType.URI });
  app.setGlobalPrefix('api/v1');

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  app.useGlobalFilters(new HttpExceptionFilter());
  app.useGlobalInterceptors(new TransformInterceptor());

  if (configService.get('NODE_ENV') !== 'production') {
    const config = new DocumentBuilder()
      .setTitle('Saksham Foundation API')
      .setDescription('NGO Management System — REST API')
      .setVersion('1.0')
      .addBearerAuth({ type: 'http', scheme: 'bearer', bearerFormat: 'JWT' }, 'JWT')
      .addTag('auth').addTag('users').addTag('donors').addTag('donations')
      .addTag('students').addTag('categories').addTag('achievements')
      .addTag('reminders').addTag('offices').addTag('reports')
      .addTag('notifications').addTag('payment-links')
      .build();
    const document = SwaggerModule.createDocument(app, config);
    SwaggerModule.setup('docs', app, document, {
      swaggerOptions: { persistAuthorization: true },
    });
  }

  const port = configService.get<number>('PORT', 3001);
  await app.listen(port, '0.0.0.0');
  console.log(`🚀 Saksham API → http://localhost:${port}/api/v1`);
  console.log(`📚 Swagger    → http://localhost:${port}/docs`);
}

bootstrap();
