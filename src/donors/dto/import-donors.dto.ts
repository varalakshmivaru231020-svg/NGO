import { IsArray, ArrayMinSize, ArrayMaxSize, ValidateNested, IsOptional, IsString, IsInt } from 'class-validator';
import { Type } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

// One spreadsheet row. Everything is optional and loosely typed on purpose:
// a bulk file always has a few bad cells, and a strict DTO would turn one
// blank mobile into a 400 for the whole upload. DonorsService.importMany()
// validates each row itself and reports per-row problems instead.
export class ImportDonorRowDto {
  @ApiPropertyOptional({ description: 'Source spreadsheet row number, echoed back in the result' })
  @IsOptional() @IsInt() row?: number;

  @ApiPropertyOptional() @IsOptional() @IsString() name?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() mobile?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() whatsapp?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() email?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() gender?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() dob?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() anniversary?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() address?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() city?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() state?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() country?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() pincode?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() occupation?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() company?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() tier?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() notes?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() pan?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() aadhaar?: string;
  @ApiPropertyOptional({ description: 'Any of: Call, WhatsApp, Email (comma-separated)' })
  @IsOptional() @IsString() preferredContactMethod?: string;
  @ApiPropertyOptional({ description: 'Donor category NAME — resolved to an id server-side' })
  @IsOptional() @IsString() category?: string;
}

export class ImportDonorsDto {
  @ApiProperty({ type: [ImportDonorRowDto] })
  @IsArray() @ArrayMinSize(1) @ArrayMaxSize(500)
  @ValidateNested({ each: true }) @Type(() => ImportDonorRowDto)
  donors: ImportDonorRowDto[];
}
