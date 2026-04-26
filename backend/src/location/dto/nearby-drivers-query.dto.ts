import { IsLatitude, IsLongitude, IsNumber, Min } from 'class-validator';

export class NearbyDriversQueryDto {
  @IsLatitude()
  lat!: number;

  @IsLongitude()
  lng!: number;

  @IsNumber()
  @Min(0.1)
  radiusKm = 2;
}
