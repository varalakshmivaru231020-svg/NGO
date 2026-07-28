import { IsOptional, IsIn, IsString, IsDateString } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { PaginationDto } from '../../common/dto/pagination.dto';

const DONATION_STATUSES = ['PENDING', 'COMPLETED', 'FAILED', 'REFUNDED'] as const;
const PAYMENT_MODES = ['CASH', 'UPI', 'BANK_TRANSFER', 'CHEQUE', 'PAYMENT_LINK', 'CARD'] as const;

export class DonationQueryDto extends PaginationDto {
  @ApiPropertyOptional({ enum: DONATION_STATUSES }) @IsOptional() @IsIn(DONATION_STATUSES) status?: string;
  @ApiPropertyOptional({ enum: PAYMENT_MODES }) @IsOptional() @IsIn(PAYMENT_MODES) paymentMode?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() donorId?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() typeId?: string;
  @ApiPropertyOptional() @IsOptional() @IsDateString() from?: string;
  @ApiPropertyOptional() @IsOptional() @IsDateString() to?: string;
}
