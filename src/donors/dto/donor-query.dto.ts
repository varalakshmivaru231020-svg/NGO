import { IsOptional, IsIn, IsString } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { PaginationDto } from '../../common/dto/pagination.dto';

const DONOR_TIERS = ['PLATINUM', 'GOLD', 'SILVER', 'BRONZE'] as const;

export class DonorQueryDto extends PaginationDto {
  @ApiPropertyOptional({ enum: DONOR_TIERS }) @IsOptional() @IsIn(DONOR_TIERS) tier?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() city?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() categoryId?: string;
}
