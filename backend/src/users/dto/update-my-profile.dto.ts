import { IsString, MaxLength, MinLength } from 'class-validator';

export class UpdateMyProfileDto {
  @IsString()
  @MinLength(3)
  @MaxLength(100)
  fullName!: string;
}
