import { Type } from 'class-transformer';
import { IsLatitude, IsLongitude, IsNumber, Min } from 'class-validator';

export class NearbyDriversQueryDto {
  @Type(() => Number)
  @IsLatitude()
  lat!: number;

  @Type(() => Number)
  @IsLongitude()
  lng!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(0.1)
  radiusKm = 2;
}
