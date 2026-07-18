import { IsString, IsIn, IsOptional, IsDateString, IsInt, IsArray, ValidateNested, Min } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { CreateStudentDocumentDto } from './create-student-document.dto';

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

  // Education Details tab
  @ApiPropertyOptional() @IsOptional() @IsString() admissionNo?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() academicYear?: string;
  @ApiPropertyOptional() @IsOptional() @IsDateString() joiningDate?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() section?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() permanence?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() studentType?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() educationRemarks?: string;

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

  // Documents picked during the Add Child flow, bundled into this same
  // request so they're created transactionally with the new student's real
  // id — including when this whole request is queued for Super Admin
  // approval (the approval-replay mechanism replays this exact payload
  // verbatim, so the documents survive replay instead of being dropped).
  @ApiPropertyOptional({ type: [CreateStudentDocumentDto] })
  @IsOptional() @IsArray() @ValidateNested({ each: true }) @Type(() => CreateStudentDocumentDto)
  documents?: CreateStudentDocumentDto[];
}
