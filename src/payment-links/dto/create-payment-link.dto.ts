import { IsString, IsInt, IsOptional, IsDateString, Min } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class CreatePaymentLinkDto {
  @ApiPropertyOptional() @IsOptional() @IsString() donorId?: string;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(1) amount?: number;
  @ApiPropertyOptional() @IsOptional() @IsString() purpose?: string;
  @ApiPropertyOptional() @IsOptional() @IsDateString() expiresAt?: string;
}
