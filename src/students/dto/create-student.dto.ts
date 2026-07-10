import { IsString, IsIn, IsOptional, IsDateString, IsInt, Min } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

const GENDERS = ['MALE', 'FEMALE', 'OTHER'] as const;
const STUDENT_STATUSES = ['ACTIVE', 'INACTIVE', 'GRADUATED', 'DROPPED'] as const;

export class CreateStudentDto {
  @ApiProperty() @IsString() name: string;
  @ApiPropertyOptional({ enum: GENDERS }) @IsOptional() @IsIn(GENDERS) gender?: string;
  @ApiProperty() @IsDateString() dob: string;
  @ApiProperty() @IsString() centerId: string;
  @ApiPropertyOptional() @IsOptional() @IsString() class?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() school?: string;
  @ApiPropertyOptional({ enum: STUDENT_STATUSES }) @IsOptional() @IsIn(STUDENT_STATUSES) status?: string;
  @ApiPropertyOptional({ description: 'Profile photo, base64-encoded' }) @IsOptional() @IsString() photo?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() fatherName?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() motherName?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() guardianName?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() guardianRelation?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() guardianPhone?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() address?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() medicalNotes?: string;
  @ApiPropertyOptional() @IsOptional() @IsDateString() admissionDate?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() notes?: string;

  // Identity / government IDs
  @ApiPropertyOptional() @IsOptional() @IsString() aadhaarNumber?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() satNumber?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() penNumber?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() cwcNumber?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() abhaNumber?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() rationCardNumber?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() missionVatsalyaNumber?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() caste?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() subCaste?: string;

  // Financial / welfare
  @ApiPropertyOptional() @IsOptional() @IsString() bankAccountDetails?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() siblingNames?: string;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) incomeCertificateAmount?: number;
  @ApiPropertyOptional() @IsOptional() @IsString() incomeCertificateRdNumber?: string;
}
