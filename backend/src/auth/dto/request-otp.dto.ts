import { IsString, Matches } from 'class-validator';

export class RequestOtpDto {
  @IsString()
  @Matches(/^\+?[1-9]\d{7,14}$/, {
    message: 'phone must be a valid international number (E.164-like format).'
  })
  phone!: string;
}
