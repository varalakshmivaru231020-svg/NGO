import { IsString, IsEmail, IsIn, IsOptional, IsBoolean, IsDateString } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

const GENDERS = ['MALE', 'FEMALE', 'OTHER'] as const;
const DONOR_TIERS = ['PLATINUM', 'GOLD', 'SILVER', 'BRONZE'] as const;

export class CreateDonorDto {
  @ApiProperty() @IsString() name: string;
  @ApiProperty() @IsString() mobile: string;
  @ApiPropertyOptional() @IsOptional() @IsString() whatsapp?: string;
  @ApiPropertyOptional() @IsOptional() @IsEmail() email?: string;
  @ApiPropertyOptional({ enum: GENDERS }) @IsOptional() @IsIn(GENDERS) gender?: string;
  @ApiPropertyOptional() @IsOptional() @IsDateString() dob?: string;
  @ApiPropertyOptional() @IsOptional() @IsDateString() anniversary?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() address?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() city?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() state?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() pincode?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() occupation?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() company?: string;
  @ApiPropertyOptional({ enum: DONOR_TIERS }) @IsOptional() @IsIn(DONOR_TIERS) tier?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() notes?: string;
  @ApiPropertyOptional({ description: 'Profile photo, base64-encoded' }) @IsOptional() @IsString() avatar?: string;
  @ApiPropertyOptional({ type: [String] }) @IsOptional() categoryIds?: string[];
}
