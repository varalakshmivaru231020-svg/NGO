import { IsDateString, IsBoolean, IsOptional, IsString } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class MarkAttendanceDto {
  @ApiProperty() @IsDateString() date: string;
  @ApiPropertyOptional() @IsOptional() @IsBoolean() present?: boolean;
  @ApiPropertyOptional() @IsOptional() @IsString() notes?: string;
}
