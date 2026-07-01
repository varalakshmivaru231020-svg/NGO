import { IsEmail, IsString, IsIn, IsOptional, MinLength } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

const ROLES = ['ADMIN', 'MANAGER', 'STAFF', 'VOLUNTEER'] as const;

export class CreateUserDto {
  @ApiProperty() @IsString() name: string;
  @ApiProperty() @IsEmail() email: string;
  @ApiProperty() @IsString() @MinLength(8) password: string;
  @ApiPropertyOptional() @IsOptional() @IsString() phone?: string;
  @ApiPropertyOptional({ enum: ROLES }) @IsOptional() @IsIn(ROLES) role?: string;
  @ApiPropertyOptional({ description: 'CSV of frontend module keys' }) @IsOptional() @IsString() modules?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() officeId?: string;
}
