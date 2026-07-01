import { IsOptional, IsString } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

// Filters for the Super Admin approval dashboard. All optional — combine freely.
export class ApprovalQueryDto {
  @ApiPropertyOptional({ description: 'PENDING | APPROVED | REJECTED' })
  @IsOptional() @IsString() status?: string;

  @ApiPropertyOptional({ description: 'Module key, e.g. donors' })
  @IsOptional() @IsString() module?: string;

  @ApiPropertyOptional({ description: 'CREATE | EDIT | DELETE' })
  @IsOptional() @IsString() action?: string;

  @ApiPropertyOptional() @IsOptional() @IsString() requesterId?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() role?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() department?: string;

  @ApiPropertyOptional({ description: 'ISO date — created from' })
  @IsOptional() @IsString() from?: string;

  @ApiPropertyOptional({ description: 'ISO date — created to' })
  @IsOptional() @IsString() to?: string;

  @ApiPropertyOptional({ description: 'Free-text search (requester, module, action)' })
  @IsOptional() @IsString() q?: string;
}
