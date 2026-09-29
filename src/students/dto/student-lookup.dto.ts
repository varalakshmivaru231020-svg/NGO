import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsInt, IsNotEmpty, IsOptional, IsString, MaxLength, Min } from 'class-validator';

export const STUDENT_LOOKUP_TYPES = ['STATUS', 'EDUCATION_LEVEL'] as const;
export type StudentLookupType = (typeof STUDENT_LOOKUP_TYPES)[number];

export class CreateStudentLookupDto {
  @ApiProperty({ example: 'Former Student' })
  @IsString() @IsNotEmpty() @MaxLength(60)
  label: string;

  @ApiPropertyOptional()
  @IsOptional() @IsString() @MaxLength(300)
  description?: string;

  @ApiPropertyOptional()
  @IsOptional() @IsInt() @Min(0)
  sortOrder?: number;
}

export class UpdateStudentLookupDto {
  @ApiPropertyOptional()
  @IsOptional() @IsString() @IsNotEmpty() @MaxLength(60)
  label?: string;

  @ApiPropertyOptional()
  @IsOptional() @IsString() @MaxLength(300)
  description?: string;

  @ApiPropertyOptional()
  @IsOptional() @IsInt() @Min(0)
  sortOrder?: number;

  @ApiPropertyOptional()
  @IsOptional() @IsBoolean()
  isActive?: boolean;
}
