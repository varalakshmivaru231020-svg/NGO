import { IsIn, IsString } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

const STATUSES = ['ACTIVE', 'PAID', 'FAILED', 'EXPIRED'] as const;

export class UpdatePaymentLinkStatusDto {
  @ApiProperty({ enum: STATUSES })
  @IsString()
  @IsIn(STATUSES)
  status: string;
}
