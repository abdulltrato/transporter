import {
  IsDateString,
  IsEnum,
  IsOptional,
  IsString,
  MaxLength,
  MinLength
} from 'class-validator';
import { UserRole } from '../../common/enums/user-role.enum';
import { SocialProvider } from '../enums/social-provider.enum';

export class SocialAuthDto {
  @IsEnum(SocialProvider)
  provider!: SocialProvider;

  @IsString()
  @MinLength(3)
  @MaxLength(191)
  providerUserId!: string;

  @IsEnum(UserRole)
  role!: UserRole;

  @IsOptional()
  @IsString()
  @MinLength(3)
  @MaxLength(100)
  fullName?: string;

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
