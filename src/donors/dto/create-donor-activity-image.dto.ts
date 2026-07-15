import { IsString, IsOptional, IsDateString, IsIn } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export const ALLOWED_IMAGE_MIME_TYPES = [
  'image/jpeg',
  'image/png',
  'image/webp',
] as const;

export class CreateDonorActivityImageDto {
  @ApiProperty() @IsString() title: string;
  @ApiPropertyOptional() @IsOptional() @IsDateString() activityDate?: string;
  @ApiProperty() @IsString() fileName: string;
  @ApiPropertyOptional({ enum: ALLOWED_IMAGE_MIME_TYPES })
  @IsOptional() @IsIn(ALLOWED_IMAGE_MIME_TYPES) mimeType?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() uploadedBy?: string;
  @ApiProperty({ description: 'Base64-encoded image content' }) @IsString() data: string;
}
