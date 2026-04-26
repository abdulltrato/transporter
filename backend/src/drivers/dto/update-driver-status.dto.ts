import { IsEnum } from 'class-validator';
import { DriverStatus } from '../../common/enums/driver-status.enum';

export class UpdateDriverStatusDto {
  @IsEnum(DriverStatus)
  status!: DriverStatus;
}
