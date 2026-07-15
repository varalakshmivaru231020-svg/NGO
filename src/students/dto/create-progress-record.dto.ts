import { IsString, IsOptional, IsDateString, IsInt, IsNumber, Min, Max } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class CreateProgressRecordDto {
  @ApiPropertyOptional() @IsOptional() @IsDateString() date?: string;
  @ApiPropertyOptional() @IsOptional() @IsInt() @Min(0) @Max(100) academicScore?: number;
  @ApiPropertyOptional() @IsOptional() @IsNumber() @Min(0) @Max(100) attendancePercent?: number;
  @ApiPropertyOptional() @IsOptional() @IsString() behaviourRating?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() communicationSkills?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() leadership?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() sportsPerformance?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() mentorRemarks?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() teacherRemarks?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() examResult?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() grade?: string;
}
