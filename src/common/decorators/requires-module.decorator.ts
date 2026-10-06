import { SetMetadata } from '@nestjs/common';

export const MODULE_KEY = 'module';
// App module key (as stored in User.modules) a route requires — see ModuleAccessGuard.
export const RequiresModule = (module: string) => SetMetadata(MODULE_KEY, module);
