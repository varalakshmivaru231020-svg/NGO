import { IsOptional, IsIn, IsString } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { PaginationDto } from '../../common/dto/pagination.dto';

const ACHIEVEMENT_CATEGORIES = ['ACADEMICS', 'SPORTS', 'ARTS', 'LIFE_SKILLS', 'COMMUNITY', 'OTHER'] as const;

export class AchievementQueryDto extends PaginationDto {
  @ApiPropertyOptional({ enum: ACHIEVEMENT_CATEGORIES }) @IsOptional() @IsIn(ACHIEVEMENT_CATEGORIES) category?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() studentId?: string;
}
