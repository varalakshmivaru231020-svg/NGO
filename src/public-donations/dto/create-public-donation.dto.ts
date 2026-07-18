import { IsString, IsEmail, IsIn, IsOptional, IsInt, Min } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

const CAUSES = ['education', 'sponsorship', 'health', 'nutrition', 'skill', 'women', 'general'] as const;

export class CreatePublicDonationDto {
  @ApiProperty() @IsString() name: string;
  @ApiProperty() @IsString() mobile: string;
  @ApiPropertyOptional() @IsOptional() @IsEmail() email?: string;
  @ApiPropertyOptional() @IsOptional() @IsString() pan?: string;
  @ApiProperty({ enum: CAUSES }) @IsIn(CAUSES) cause: string;
  @ApiProperty() @IsInt() @Min(100) amount: number;
}
