import {
  IsEnum,
  IsOptional,
  IsString,
  MaxLength,
  MinLength
} from 'class-validator';
import { SubscriptionPaymentMethod } from '../enums/subscription-payment-method.enum';
import { SubscriptionPlan } from '../enums/subscription-plan.enum';

export class RequestSubscriptionPaymentDto {
  @IsEnum(SubscriptionPlan)
  plan!: SubscriptionPlan;

  @IsEnum(SubscriptionPaymentMethod)
  paymentMethod!: SubscriptionPaymentMethod;

  @IsString()
  @MinLength(4)
  @MaxLength(64)
  paymentReference!: string;

  @IsOptional()
  @IsString()
  @MaxLength(240)
  paymentNotes?: string;
}
