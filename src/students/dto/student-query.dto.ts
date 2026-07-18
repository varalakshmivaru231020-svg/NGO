import { IsOptional, IsIn, IsString } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { PaginationDto } from '../../common/dto/pagination.dto';

const STUDENT_STATUSES = ['ACTIVE', 'INACTIVE', 'GRADUATED', 'DROPPED'] as const;

export class StudentQueryDto extends PaginationDto {
  @ApiPropertyOptional({ enum: STUDENT_STATUSES }) @IsOptional() @IsIn(STUDENT_STATUSES) status?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() centerId?: string;
  @ApiPropertyOptional({ description: 'Only students with an active sponsorship from this donor' })
  @IsOptional() @IsString() sponsorDonorId?: string;
}
