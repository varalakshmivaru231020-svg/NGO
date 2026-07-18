import { IsOptional, IsString } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class UpdateOrganizationSettingsDto {
  @ApiPropertyOptional() @IsOptional() @IsString() name?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() address?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() city?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() state?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() country?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() pincode?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() phone?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() email?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() website?: string;
  @ApiPropertyOptional({ description: 'Trust/Society registration number' })
  @IsOptional() @IsString() registrationNumber?: string;
  @ApiPropertyOptional({ description: 'PAN number' })
  @IsOptional() @IsString() pan?: string;
  @ApiPropertyOptional({ description: '12A/12AA certificate number' })
  @IsOptional() @IsString() reg12A?: string;
  @ApiPropertyOptional({ description: '80G approval number' })
  @IsOptional() @IsString() cert80G?: string;
  @ApiPropertyOptional({ description: 'FCRA status/number' })
  @IsOptional() @IsString() fcra?: string;
  @ApiPropertyOptional({ description: 'Base64-encoded logo image' })
  @IsOptional() @IsString() logoBase64?: string;
}
