import { IsOptional, IsString, IsNotEmpty } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

// Real DTO classes so the global ValidationPipe (whitelist +
// forbidNonWhitelisted) actually runs — inline-typed bodies skip validation
// entirely and pass straight into Prisma `data` (mass assignment).
export class CreateCenterDto {
  @ApiProperty() @IsString() @IsNotEmpty() name: string;
  @ApiPropertyOptional() @IsOptional() @IsString() city?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() address?: string;
}

export class UpdateCenterDto {
  @ApiPropertyOptional() @IsOptional() @IsString() name?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() city?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() address?: string;
}
