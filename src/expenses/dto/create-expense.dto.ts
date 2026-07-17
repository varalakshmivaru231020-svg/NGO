import { IsString, IsInt, IsIn, IsOptional, IsDateString, Min } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

const PAYMENT_MODES = ['CASH', 'UPI', 'BANK_TRANSFER', 'CHEQUE', 'CARD'] as const;

export class CreateExpenseDto {
  @ApiProperty() @IsString() categoryId: string;
  @ApiProperty() @IsString() paidTo: string;
  @ApiProperty() @IsString() purpose: string;
  @ApiProperty() @IsInt() @Min(1) amount: number;
  @ApiPropertyOptional({ enum: PAYMENT_MODES }) @IsOptional() @IsIn(PAYMENT_MODES) paymentMode?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() reference?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() chequeNo?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() bankName?: string;
  // Who filled out this voucher — client-submitted (not derived from req.user) so it
  // survives the approval-replay flow unchanged; see ExpensesService.create().
  @ApiPropertyOptional() @IsOptional() @IsString() preparedBy?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() receivedBy?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() notes?: string;
  @ApiPropertyOptional() @IsOptional() @IsDateString() date?: string;
}
