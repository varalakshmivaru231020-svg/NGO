import { NestFactory } from '@nestjs/core';
import { ValidationPipe, VersioningType } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import helmet from 'helmet';
import cookieParser from 'cookie-parser';
import { json, urlencoded, static as expressStatic } from 'express';
import { existsSync } from 'fs';
import { join } from 'path';
import { AppModule } from './app.module';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { TransformInterceptor } from './common/interceptors/transform.interceptor';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    logger: ['error', 'warn', 'log'],
    bodyParser: false, // replaced below with a higher limit (base64 photos)
  });

  const configService = app.get(ConfigService);

  // Behind nginx (CloudPanel/docker) — without this every request carries the
  // proxy's IP, so the global rate limiter throttles the whole internet as
  // one client and per-IP login protection does nothing.
  app.getHttpAdapter().getInstance().set('trust proxy', 1);

  // CSP is disabled: this same server now also serves the Flutter web build
  // (see the static-file section below), which loads external resources
  // (Google Fonts, CanvasKit WASM) that helmet's default strict CSP would
  // otherwise block. Other helmet protections (XSS filter, hide
  // X-Powered-By, etc.) stay on.
  app.use(helmet({ contentSecurityPolicy: false }));
  app.use(cookieParser());
  // Allow base64 images (avatars / student photos) and short activity
  // videos (up to ~20MB original, ~27MB once base64-encoded) in JSON bodies.
  app.use(
    json({
      limit: '30mb',
      // Stash the raw request body alongside normal parsing — needed to
      // verify the Razorpay webhook's HMAC signature, which must be computed
      // over the exact bytes Razorpay sent. req.body is still populated
      // normally for every route; this is a harmless no-op elsewhere.
      verify: (req: any, _res, buf: Buffer) => {
        req.rawBody = buf;
      },
    }),
  );
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
    'http://localhost:3008',
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
      .addTag('notifications').addTag('payment-links').addTag('public-donations')
      .build();
    const document = SwaggerModule.createDocument(app, config);
    SwaggerModule.setup('docs', app, document, {
      swaggerOptions: { persistAuthorization: true },
    });
  }

  // ── Serve the Flutter web build from this same server ──────────────────
  // One deployable Node.js process handles both the API (/api/v1/*, /docs)
  // and the app's web UI, instead of running two separate sites. The build
  // folder is copied to WEB_BUILD_PATH at deploy time (defaults to
  // saksham-backend/public/web) — if it isn't present (e.g. plain local
  // API-only dev), this section is skipped entirely.
  // __dirname here is dist/src (this file always runs compiled — both
  // `nest start --watch` and production run node against dist/src/main.js),
  // so the project root is two levels up, not one.
  // ── Downloadable files (the Android APK) ───────────────────────────────
  // Deliberately public/downloads and NOT public/web: deploys swap the whole
  // web folder out, so anything parked in there is lost on the next release.
  // Mounted before the SPA fallback below, which would otherwise answer these
  // paths with index.html.
  const downloadsPath = join(__dirname, '..', '..', 'public', 'downloads');
  if (existsSync(downloadsPath)) {
    app.use('/download', expressStatic(downloadsPath));
    console.log(`⬇️  Downloads  → serving from ${downloadsPath}`);
  }

  const webBuildPath = configService.get<string>('WEB_BUILD_PATH')
    ?? join(__dirname, '..', '..', 'public', 'web');
  if (existsSync(join(webBuildPath, 'index.html'))) {
    app.use(expressStatic(webBuildPath));
    app.use((req, res, next) => {
      if (req.method !== 'GET' || req.path.startsWith('/api/') || req.path.startsWith('/docs')) {
        return next();
      }
      res.sendFile(join(webBuildPath, 'index.html'));
    });
    console.log(`🌐 Web app    → serving from ${webBuildPath}`);
  } else {
    console.log(`🌐 Web app    → not found at ${webBuildPath}, skipping (API-only mode)`);
  }

  const port = configService.get<number>('PORT', 3001);
  await app.listen(port, '0.0.0.0');
  console.log(`🚀 Saksham API → http://localhost:${port}/api/v1`);
  console.log(`📚 Swagger    → http://localhost:${port}/docs`);
}

bootstrap();
