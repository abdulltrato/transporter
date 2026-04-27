import { IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';

export class SubmitDriverRatingDto {
  @IsString()
  @MaxLength(80)
  rideId!: string;

  @IsInt()
  @Min(1)
  @Max(5)
  stars!: number;

  @IsOptional()
  @IsString()
  @MaxLength(240)
  comment?: string;
}
