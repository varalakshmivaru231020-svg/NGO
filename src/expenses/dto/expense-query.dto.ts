import { IsOptional, IsIn, IsString } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { PaginationDto } from '../../common/dto/pagination.dto';

const EXPENSE_STATUSES = ['PENDING', 'COMPLETED', 'CANCELLED'] as const;
const PAYMENT_MODES = ['CASH', 'UPI', 'BANK_TRANSFER', 'CHEQUE', 'CARD'] as const;

export class ExpenseQueryDto extends PaginationDto {
  @ApiPropertyOptional({ enum: EXPENSE_STATUSES }) @IsOptional() @IsIn(EXPENSE_STATUSES) status?: string;
  @ApiPropertyOptional({ enum: PAYMENT_MODES }) @IsOptional() @IsIn(PAYMENT_MODES) paymentMode?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() categoryId?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() from?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() to?: string;
}
