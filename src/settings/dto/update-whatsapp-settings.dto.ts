import { IsOptional, IsString } from 'class-validator';
import { ApiPropertyOptional } from '@nestjs/swagger';

export class UpdateWhatsappSettingsDto {
  @ApiPropertyOptional({ description: 'Sender display number, e.g. 919832399399' })
  @IsOptional() @IsString() storeNumber?: string;

  @ApiPropertyOptional({ description: 'Meta Phone Number ID' })
  @IsOptional() @IsString() phoneNumberId?: string;

  @ApiPropertyOptional({ description: 'Bearer API token' })
  @IsOptional() @IsString() apiToken?: string;

  @ApiPropertyOptional({ description: 'Send endpoint (optional override)' })
  @IsOptional() @IsString() apiUrl?: string;

  @ApiPropertyOptional({ description: 'Meta Graph API version, e.g. v19.0 (native-Meta mode only)' })
  @IsOptional() @IsString() apiVersion?: string;

  @ApiPropertyOptional({ description: 'WhatsApp Business Account ID (reference only)' })
  @IsOptional() @IsString() wabaId?: string;

  @ApiPropertyOptional({ description: 'Meta Business ID (reference only)' })
  @IsOptional() @IsString() businessId?: string;
}
