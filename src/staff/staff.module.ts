import { Module } from '@nestjs/common';
import { StaffController } from './staff.controller';
import { StaffService } from './staff.service';
import { ModuleAccessGuard } from '../common/guards/module-access.guard';

@Module({
  controllers: [StaffController],
  providers: [StaffService, ModuleAccessGuard],
  exports: [StaffService],
})
export class StaffModule {}
