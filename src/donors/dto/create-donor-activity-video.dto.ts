import { IsString, IsOptional, IsDateString, IsIn } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export const ALLOWED_VIDEO_MIME_TYPES = [
  'video/mp4',
  'video/quicktime', // .mov
  'video/x-msvideo', // .avi
  'video/webm',
] as const;

export class CreateDonorActivityVideoDto {
  @ApiProperty() @IsString() title: string;
  @ApiPropertyOptional() @IsOptional() @IsDateString() activityDate?: string;
  @ApiProperty() @IsString() fileName: string;
  @ApiPropertyOptional({ enum: ALLOWED_VIDEO_MIME_TYPES })
  @IsOptional() @IsIn(ALLOWED_VIDEO_MIME_TYPES) mimeType?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() uploadedBy?: string;
  @ApiProperty({ description: 'Base64-encoded video content' }) @IsString() data: string;
}
