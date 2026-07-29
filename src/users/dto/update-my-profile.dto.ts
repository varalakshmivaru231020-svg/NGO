import { IsOptional, IsString, MaxLength } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

// Self-service profile edit — deliberately narrow (no role/modules/email
// changes; those stay admin-managed via PATCH /users/:id).
export class UpdateMyProfileDto {
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(120) name?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() @MaxLength(30) phone?: string;
  @ApiPropertyOptional({ description: 'Profile photo, base64-encoded' })
  @IsOptional() @IsString() avatar?: string;
}
