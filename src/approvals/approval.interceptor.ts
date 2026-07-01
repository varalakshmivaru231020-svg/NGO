import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
} from '@nestjs/common';
import { Observable, from, of } from 'rxjs';
import { switchMap } from 'rxjs/operators';
import { ApprovalsService } from './approvals.service';

// Global interceptor (registered via APP_INTERCEPTOR). Runs after the auth
// guard, so req.user is populated. Every Create/Edit/Delete by a non-SUPER_ADMIN
// is short-circuited into a PENDING ApprovalRequest instead of executing.
// SUPER_ADMIN and internal replay requests pass straight through.
@Injectable()
export class ApprovalInterceptor implements NestInterceptor {
  constructor(private approvals: ApprovalsService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const req = context.switchToHttp().getRequest();
    if (!this.approvals.shouldIntercept(req)) {
      return next.handle();
    }
    return from(this.approvals.createFromRequest(req)).pipe(
      switchMap((created) =>
        of({
          success: true,
          data: {
            id: created.id,
            status: 'PENDING',
            module: created.module,
            action: created.action,
          },
          message: 'Submitted for Super Admin approval',
          meta: { pendingApproval: true },
        }),
      ),
    );
  }
}
