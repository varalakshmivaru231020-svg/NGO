import { IsString, IsOptional, IsDateString, IsBoolean } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateReminderDto {
  @ApiPropertyOptional() @IsOptional() @IsString() donorId?: string;
  @ApiProperty() @IsString() type: string;
  @ApiProperty() @IsString() title: string;
  @ApiPropertyOptional() @IsOptional() @IsString() message?: string;
  @ApiProperty() @IsDateString() dueDate: string;
}
