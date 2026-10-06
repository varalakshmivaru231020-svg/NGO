import { IsOptional, IsIn, IsString } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { STAFF_EMPLOYMENT_TYPES } from './create-staff.dto';

export class StaffQueryDto extends PaginationDto {
  @ApiPropertyOptional({ description: 'StaffLookup STATUS key' }) @IsOptional() @IsString() status?: string;
  @ApiPropertyOptional({ enum: STAFF_EMPLOYMENT_TYPES }) @IsOptional() @IsIn(STAFF_EMPLOYMENT_TYPES) employmentType?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() centerId?: string;
}
