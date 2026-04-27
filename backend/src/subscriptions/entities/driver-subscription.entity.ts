import { SubscriptionPaymentMethod } from '../enums/subscription-payment-method.enum';
import { SubscriptionPlan } from '../enums/subscription-plan.enum';
import { SubscriptionStatus } from '../enums/subscription-status.enum';

export interface DriverSubscriptionEntity {
  id: string;
  driverId: string;
  plan: SubscriptionPlan;
  paymentMethod: SubscriptionPaymentMethod;
  paymentReference: string;
  status: SubscriptionStatus;
  validationAvailableAt: Date;
  validatedAt?: Date;
  startsAt?: Date;
  endsAt?: Date;
  agentName?: string;
  agentNotes?: string;
  createdAt: Date;
  updatedAt: Date;
}
