import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsBoolean, IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

export class CreateDonationTypeDto {
  @ApiProperty({ example: 'Student Sponsorship' })
  @IsString() @IsNotEmpty() @MaxLength(60)
  label: string;

  @ApiPropertyOptional({ example: 'Sponsor a student’s education for a year' })
  @IsOptional() @IsString() @MaxLength(300)
  description?: string;

  @ApiPropertyOptional({ example: 'school' })
  @IsOptional() @IsString() @MaxLength(40)
  icon?: string;
}

export class UpdateDonationTypeDto {
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
