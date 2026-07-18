import { IsOptional, IsString } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateUserDocumentDto {
  @ApiProperty({ description: 'Bucket label, e.g. "ID Proof", "Certifications"' }) @IsString() category: string;
  @ApiProperty() @IsString() fileName: string;
  @ApiPropertyOptional() @IsOptional() @IsString() mimeType?: string;
  @ApiProperty({ description: 'Base64-encoded file content' }) @IsString() data: string;
}
