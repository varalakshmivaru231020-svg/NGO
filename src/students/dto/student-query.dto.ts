import { IsOptional, IsString } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';
import { PaginationDto } from '../../common/dto/pagination.dto';


export class StudentQueryDto extends PaginationDto {
  @ApiPropertyOptional({ description: 'StudentLookup key of type STATUS (Settings → Student Status)' })
  @IsOptional() @IsString() status?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() centerId?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() categoryId?: string;
  @ApiPropertyOptional({ description: 'Only students with an active sponsorship from this donor' })
  @IsOptional() @IsString() sponsorDonorId?: string;
}
