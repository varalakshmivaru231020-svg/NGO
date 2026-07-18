import { IsOptional, IsString } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class UpdateRazorpaySettingsDto {
  @ApiPropertyOptional({ description: 'Razorpay Key ID, e.g. rzp_live_xxxxxxxx' })
  @IsOptional() @IsString() keyId?: string;

  @ApiPropertyOptional({ description: 'Razorpay Key Secret — used server-side only' })
  @IsOptional() @IsString() keySecret?: string;

  @ApiPropertyOptional({ description: 'Webhook Secret configured in the Razorpay Dashboard — used to verify incoming webhook signatures' })
  @IsOptional() @IsString() webhookSecret?: string;
}
