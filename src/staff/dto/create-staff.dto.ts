import { IsString, IsIn, IsOptional, IsDateString, IsInt, IsArray, IsBoolean, IsEmail, ValidateNested, Min, MinLength } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export const STAFF_GENDERS = ['MALE', 'FEMALE', 'OTHER'] as const;
export const STAFF_EMPLOYMENT_TYPES = ['FULL_TIME', 'PART_TIME', 'CONTRACT', 'VOLUNTEER'] as const;

export class StaffChildDto {
  @ApiProperty() @IsString() @MinLength(1) name: string;
  @ApiPropertyOptional({ example: 'Son' }) @IsOptional() @IsString() relation?: string;
  @ApiPropertyOptional() @IsOptional() @IsDateString() dob?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() school?: string;
}

export class CreateStaffDto {
  @ApiProperty() @IsString() @MinLength(1) name: string;
  @ApiPropertyOptional({ enum: STAFF_GENDERS }) @IsOptional() @IsIn(STAFF_GENDERS) gender?: string;
  @ApiPropertyOptional() @IsOptional() @IsDateString() dob?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() mobile?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() whatsapp?: string;
  @ApiPropertyOptional() @IsOptional() @IsEmail() email?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() address?: string;
  @ApiPropertyOptional({ description: 'Profile photo, base64-encoded' }) @IsOptional() @IsString() photo?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() aadhaarNumber?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() panNumber?: string;

  @ApiProperty({ example: 'Teacher' }) @IsString() @MinLength(1) designation: string;
  @ApiPropertyOptional({ description: 'Center id; empty string clears it' }) @IsOptional() @IsString() centerId?: string;
  @ApiPropertyOptional() @IsOptional() @IsDateString() joiningDate?: string;
  @ApiPropertyOptional({ enum: STAFF_EMPLOYMENT_TYPES }) @IsOptional() @IsIn(STAFF_EMPLOYMENT_TYPES) employmentType?: string;
  @ApiPropertyOptional({ description: 'StaffLookup key of type STATUS (ACTIVE, ON_LEAVE, … or one added with "+")' })
  @IsOptional() @IsString() status?: string;
  @ApiPropertyOptional({ example: '9:00 AM - 6:00 PM' }) @IsOptional() @IsString() workTimings?: string;

  @ApiPropertyOptional({ description: 'Monthly basic, whole rupees' }) @IsOptional() @IsInt() @Min(0) basicSalary?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) hra?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) allowances?: number;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() pfApplicable?: boolean;

  @ApiPropertyOptional() @IsOptional() @IsString() bankName?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() accountNumber?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() ifscCode?: string;

  @ApiPropertyOptional() @IsOptional() @IsString() emergencyContactName?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() emergencyContactPhone?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() notes?: string;

  // Sent as the full list: on update it replaces the existing children, so
  // the form can add, edit and remove rows in one save (and one approval).
  @ApiPropertyOptional({ type: [StaffChildDto] })
  @IsOptional() @IsArray() @ValidateNested({ each: true }) @Type(() => StaffChildDto)
  children?: StaffChildDto[];
}
