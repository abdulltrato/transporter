import { IsLatitude, IsLongitude } from 'class-validator';

export class UpdateMyLocationDto {
  @IsLatitude()
  lat!: number;

  @IsLongitude()
  lng!: number;
}
