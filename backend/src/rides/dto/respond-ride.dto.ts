import { IsEnum } from 'class-validator';

export enum RideResponseAction {
  ACCEPT = 'accept',
  REJECT = 'reject'
}

export class RespondRideDto {
  @IsEnum(RideResponseAction)
  action!: RideResponseAction;
}
