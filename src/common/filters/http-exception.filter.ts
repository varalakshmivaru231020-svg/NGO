import { ExceptionFilter, Catch, ArgumentsHost, HttpException, HttpStatus, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { Request, Response } from 'express';

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(HttpExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message = 'Internal server error';
    let errors: any = undefined;

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const res = exception.getResponse();
      if (typeof res === 'string') {
        message = res;
      } else if (typeof res === 'object') {
        const r = res as any;
        message = r.message || message;
        if (Array.isArray(r.message)) {
          errors = r.message;
          message = 'Validation failed';
        }
      }
    } else if (
      exception instanceof Prisma.PrismaClientKnownRequestError &&
      exception.code === 'P2025'
    ) {
      // Update/delete of a row that no longer exists (double-click delete,
      // stale UI) — a 404, not an internal error.
      status = HttpStatus.NOT_FOUND;
      message = 'Record not found — it may have already been deleted';
    } else if (
      exception instanceof Prisma.PrismaClientKnownRequestError &&
      exception.code === 'P2002'
    ) {
      // Unique-constraint violation — surface which field collided instead of
      // a bare 500 (this also flows into approval-replay failure messages).
      status = HttpStatus.CONFLICT;
      const target = (exception.meta as any)?.target;
      const fields = Array.isArray(target) ? target.join(', ') : target;
      message = `A record with this ${fields || 'value'} already exists`;
    } else {
      this.logger.error('Unhandled exception', exception instanceof Error ? exception.stack : exception);
    }

    response.status(status).json({
      success: false,
      statusCode: status,
      message,
      errors,
      path: request.url,
      timestamp: new Date().toISOString(),
    });
  }
}
