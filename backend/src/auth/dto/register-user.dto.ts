import {
  IsDateString,
  IsEnum,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength
} from 'class-validator';
import { UserRole } from '../../common/enums/user-role.enum';

export class RegisterUserDto {
  @IsString()
  @Matches(/^\+?[1-9]\d{7,14}$/, {
    message: 'phone must be a valid international number (E.164-like format).'
  })
  phone!: string;

  @IsEnum(UserRole)
  role!: UserRole;

  @IsString()
  @MinLength(3)
  @MaxLength(100)
  fullName!: string;

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
