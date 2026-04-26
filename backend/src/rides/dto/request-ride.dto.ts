import { Type } from 'class-transformer';
import {
  IsLatitude,
  IsLongitude,
  IsOptional,
  ValidateNested
} from 'class-validator';

export class CoordinatesDto {
  @IsLatitude()
  lat!: number;

  @IsLongitude()
  lng!: number;
}

export class RequestRideDto {
  @ValidateNested()
  @Type(() => CoordinatesDto)
  pickup!: CoordinatesDto;

  @IsOptional()
  @ValidateNested()
  @Type(() => CoordinatesDto)
  dropoff?: CoordinatesDto;
}
