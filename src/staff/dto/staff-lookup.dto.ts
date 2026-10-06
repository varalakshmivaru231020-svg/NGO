import { IsString, IsNotEmpty, MaxLength } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export const STAFF_LOOKUP_TYPES = ['DESIGNATION', 'STATUS'] as const;
export type StaffLookupType = (typeof STAFF_LOOKUP_TYPES)[number];

export class CreateStaffLookupDto {
  @ApiProperty({ example: 'Librarian' }) @IsString() @IsNotEmpty() @MaxLength(60) label: string;
}
