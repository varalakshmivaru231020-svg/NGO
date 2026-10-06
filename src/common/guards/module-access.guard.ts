import { Injectable, CanActivate, ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { MODULE_KEY } from '../decorators/requires-module.decorator';
import { PrismaService } from '../../prisma/prisma.service';

// Server-side half of the app's module permissions. User.modules is the CSV
// the app writes from the member's role (Settings → Manage Roles). Most
// modules are only hidden in the app; use this where the data itself is
// sensitive (staff salary / PAN / bank details). ADMIN and SUPER_ADMIN pass,
// matching the app, where both see every module.
@Injectable()
export class ModuleAccessGuard implements CanActivate {
  constructor(private reflector: Reflector, private prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const module = this.reflector.getAllAndOverride<string>(MODULE_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!module) return true;
    const { user } = context.switchToHttp().getRequest();
    if (user?.role === 'SUPER_ADMIN' || user?.role === 'ADMIN') return true;
    if (user?.id) {
      const row = await this.prisma.user.findUnique({ where: { id: user.id }, select: { modules: true } });
      const modules = (row?.modules ?? '').split(',').map((m) => m.trim());
      if (modules.includes(module)) return true;
    }
    throw new ForbiddenException('Your role does not have access to this section');
  }
}
