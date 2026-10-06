import { IsString, IsIn, IsOptional, IsDateString, IsInt, IsNumber, IsBoolean, Matches, Min, Max } from 'class-validator';
import { ApiProperty, ApiPropertyOptional, PartialType } from '@nestjs/swagger';

export const SALARY_STATUSES = ['PENDING', 'PAID'] as const;

// One month's salary for one staff member. Amounts are whole rupees.
export class CreateStaffSalaryDto {
  @ApiProperty({ example: '2026-01', description: 'YYYY-MM' })
  @Matches(/^\d{4}-(0[1-9]|1[0-2])$/, { message: 'month must be YYYY-MM' }) month: string;

  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) basic?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) hra?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) allowances?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) overtime?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) bonus?: number;

  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) leaveDeduction?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) pf?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) advance?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) otherDeduction?: number;

  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) @Max(31) workingDays?: number;
  @ApiPropertyOptional({ description: 'Half days allowed, e.g. 1.5' }) @IsOptional() @IsNumber() @Min(0) @Max(31) leaveDays?: number;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() workedOnHolidays?: boolean;

  @ApiPropertyOptional({ enum: SALARY_STATUSES }) @IsOptional() @IsIn(SALARY_STATUSES) status?: string;
  @ApiPropertyOptional() @IsOptional() @IsDateString() paidOn?: string;
  @ApiPropertyOptional({ example: 'BANK_TRANSFER' }) @IsOptional() @IsString() paymentMode?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() notes?: string;
}

export class UpdateStaffSalaryDto extends PartialType(CreateStaffSalaryDto) {}
