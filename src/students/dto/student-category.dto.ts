import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateStudentCategoryDto {
  @ApiProperty({ example: 'Orphan' })
  @IsString() @IsNotEmpty() @MaxLength(60)
  label: string;

  @ApiPropertyOptional({ example: 'Children who have lost both parents' })
  @IsOptional() @IsString() @MaxLength(300)
  description?: string;
}

export class UpdateStudentCategoryDto {
  @ApiPropertyOptional()
  @IsOptional() @IsString() @IsNotEmpty() @MaxLength(60)
  label?: string;

  @ApiPropertyOptional()
  @IsOptional() @IsString() @MaxLength(300)
  description?: string;

  @ApiPropertyOptional()
  @IsOptional() @IsBoolean()
  isActive?: boolean;
}
