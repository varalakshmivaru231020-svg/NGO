import { IsString, IsIn, IsOptional, IsInt, IsDateString, Min } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

const ACHIEVEMENT_CATEGORIES = ['ACADEMICS', 'SPORTS', 'ARTS', 'LIFE_SKILLS', 'COMMUNITY', 'OTHER'] as const;

export class CreateAchievementDto {
  @ApiProperty() @IsString() studentId: string;
  @ApiProperty() @IsString() title: string;
  @ApiPropertyOptional() @IsOptional() @IsString() description?: string;
  @ApiPropertyOptional({ enum: ACHIEVEMENT_CATEGORIES }) @IsOptional() @IsIn(ACHIEVEMENT_CATEGORIES) category?: string;
  @ApiPropertyOptional() @IsOptional() @IsDateString() date?: string;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) photos?: number;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) videos?: number;
}
