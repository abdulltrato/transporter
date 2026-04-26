import {
  IsDateString,
  IsOptional,
  IsString,
  MaxLength,
  MinLength
} from 'class-validator';

export class UpdateDriverProfileDto {
  @IsOptional()
  @IsString()
  @MinLength(5)
  @MaxLength(40)
  documentId?: string;

  @IsOptional()
  @IsDateString()
  documentExpiry?: string;

  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(80)
  neighborhood?: string;

  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(80)
  operatingRegion?: string;
}
