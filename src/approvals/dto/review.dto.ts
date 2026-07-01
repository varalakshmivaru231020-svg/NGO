import { IsArray, IsOptional, IsString, MinLength } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class RejectDto {
  @ApiProperty({ description: 'Mandatory rejection reason' })
  @IsString() @MinLength(3) reason: string;
}

export class BulkApproveDto {
  @ApiProperty({ type: [String] })
  @IsArray() @IsString({ each: true }) ids: string[];
}

export class BulkRejectDto {
  @ApiProperty({ type: [String] })
  @IsArray() @IsString({ each: true }) ids: string[];

  @ApiProperty({ description: 'Mandatory rejection reason' })
  @IsString() @MinLength(3) reason: string;
}

// Approve takes no body fields today, but kept for future (e.g. approver note).
export class ApproveDto {
  @ApiPropertyOptional() @IsOptional() @IsString() note?: string;
}
