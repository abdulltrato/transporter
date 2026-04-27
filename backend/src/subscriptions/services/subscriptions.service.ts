import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  UnauthorizedException
} from '@nestjs/common';
import { UserRole } from '../../common/enums/user-role.enum';
import { RequestUser } from '../../common/interfaces/request-user.interface';
import { isAuthorizationBypassEnabled } from '../../common/utils/auth-bypass.util';
import {
  AgentValidateSubscriptionDto,
  AgentValidationAction
} from '../dto/agent-validate-subscription.dto';
import { RequestSubscriptionPaymentDto } from '../dto/request-subscription-payment.dto';
import { DriverSubscriptionEntity } from '../entities/driver-subscription.entity';
import { DriverSubscriptionsRepository } from '../repositories/driver-subscriptions.repository';
import { SubscriptionPlan } from '../enums/subscription-plan.enum';
import { SubscriptionStatus } from '../enums/subscription-status.enum';

@Injectable()
export class SubscriptionsService {
  private readonly validationDelayMinutes = 30;

  constructor(
    private readonly subscriptionsRepository: DriverSubscriptionsRepository
  ) {}

  async requestPayment(
    currentUser: RequestUser,
    input: RequestSubscriptionPaymentDto
  ): Promise<DriverSubscriptionEntity> {
    if (!isAuthorizationBypassEnabled() && currentUser.role !== UserRole.DRIVER) {
      throw new ForbiddenException('Only drivers can submit subscription payments.');
    }

    await this.subscriptionsRepository.expirePastSubscriptions(currentUser.id);

    const pending = await this.subscriptionsRepository.findLatestPendingByDriverId(
      currentUser.id
    );
    if (pending) {
      const availableAtMs = pending.validationAvailableAt.getTime();
      const remainingMinutes = Math.max(
        1,
        Math.ceil((availableAtMs - Date.now()) / (60 * 1000))
      );
      throw new BadRequestException(
        `You already have a pending validation. Wait up to ${remainingMinutes} minute(s) before requesting again.`
      );
    }

    const validationAvailableAt = new Date(
      Date.now() + this.validationDelayMinutes * 60 * 1000
    );

    return this.subscriptionsRepository.create({
      driverId: currentUser.id,
      plan: input.plan,
      paymentMethod: input.paymentMethod,
      paymentReference: input.paymentReference.trim(),
      status: SubscriptionStatus.PENDING_VALIDATION,
      validationAvailableAt,
      agentNotes: input.paymentNotes?.trim()
    });
  }

  async getMyCurrentSubscription(
    currentUser: RequestUser
  ): Promise<DriverSubscriptionEntity | undefined> {
    if (!isAuthorizationBypassEnabled() && currentUser.role !== UserRole.DRIVER) {
      throw new ForbiddenException('Only drivers can view subscriptions.');
    }

    await this.subscriptionsRepository.expirePastSubscriptions(currentUser.id);

    const active = await this.subscriptionsRepository.findLatestActiveByDriverId(
      currentUser.id
    );
    if (active) {
      return active;
    }

    return this.subscriptionsRepository.findLatestPendingByDriverId(currentUser.id);
  }

  async listMySubscriptions(currentUser: RequestUser): Promise<DriverSubscriptionEntity[]> {
    if (!isAuthorizationBypassEnabled() && currentUser.role !== UserRole.DRIVER) {
      throw new ForbiddenException('Only drivers can list subscriptions.');
    }

    await this.subscriptionsRepository.expirePastSubscriptions(currentUser.id);
    return this.subscriptionsRepository.listByDriverId(currentUser.id);
  }

  async assertDriverCanOperate(driverId: string): Promise<void> {
    if (isAuthorizationBypassEnabled()) {
      return;
    }

    await this.subscriptionsRepository.expirePastSubscriptions(driverId);

    const active = await this.subscriptionsRepository.findLatestActiveByDriverId(
      driverId
    );
    if (!active) {
      throw new BadRequestException(
        'Driver subscription is required. Submit payment via M-Pesa/eMola and wait for manual validation.'
      );
    }
  }

  async listPendingForAgents(agentKey?: string): Promise<DriverSubscriptionEntity[]> {
    this.assertAgentKey(agentKey);
    return this.subscriptionsRepository.listPendingValidation();
  }

  async validateByAgent(input: {
    subscriptionId: string;
    payload: AgentValidateSubscriptionDto;
    agentKey?: string;
  }): Promise<DriverSubscriptionEntity> {
    this.assertAgentKey(input.agentKey);

    const subscription = await this.subscriptionsRepository.findById(
      input.subscriptionId
    );
    if (!subscription) {
      throw new BadRequestException('Subscription request not found.');
    }

    if (subscription.status !== SubscriptionStatus.PENDING_VALIDATION) {
      throw new BadRequestException('Subscription is no longer pending validation.');
    }

    const now = Date.now();
    const availableAt = subscription.validationAvailableAt.getTime();
    if (availableAt > now) {
      const waitMinutes = Math.max(
        1,
        Math.ceil((availableAt - now) / (60 * 1000))
      );
      throw new BadRequestException(
        `Validation can only happen after 30 minutes. Remaining: ${waitMinutes} minute(s).`
      );
    }

    if (input.payload.action === AgentValidationAction.REJECT) {
      return this.subscriptionsRepository.save({
        ...subscription,
        status: SubscriptionStatus.REJECTED,
        validatedAt: new Date(now),
        agentName: input.payload.agentName.trim(),
        agentNotes: input.payload.notes?.trim()
      });
    }

    await this.subscriptionsRepository.expireAllActiveSubscriptions(
      subscription.driverId
    );

    const startsAt = new Date(now);
    const endsAt = this.addDays(startsAt, this.getPlanDurationDays(subscription.plan));

    return this.subscriptionsRepository.save({
      ...subscription,
      status: SubscriptionStatus.ACTIVE,
      validatedAt: startsAt,
      startsAt,
      endsAt,
      agentName: input.payload.agentName.trim(),
      agentNotes: input.payload.notes?.trim()
    });
  }

  toPublicSubscription(
    subscription: DriverSubscriptionEntity
  ): {
    id: string;
    driverId: string;
    plan: SubscriptionPlan;
    paymentMethod: DriverSubscriptionEntity['paymentMethod'];
    paymentReference: string;
    status: DriverSubscriptionEntity['status'];
    validationAvailableAt: Date;
    validatedAt?: Date;
    startsAt?: Date;
    endsAt?: Date;
    agentName?: string;
    agentNotes?: string;
    createdAt: Date;
    updatedAt: Date;
    usageLabel: string;
  } {
    return {
      id: subscription.id,
      driverId: subscription.driverId,
      plan: subscription.plan,
      paymentMethod: subscription.paymentMethod,
      paymentReference: subscription.paymentReference,
      status: subscription.status,
      validationAvailableAt: subscription.validationAvailableAt,
      validatedAt: subscription.validatedAt,
      startsAt: subscription.startsAt,
      endsAt: subscription.endsAt,
      agentName: subscription.agentName,
      agentNotes: subscription.agentNotes,
      createdAt: subscription.createdAt,
      updatedAt: subscription.updatedAt,
      usageLabel: this.getPlanUsageLabel(subscription.plan)
    };
  }

  private getPlanDurationDays(plan: SubscriptionPlan): number {
    return (
      {
        [SubscriptionPlan.MONTHLY]: 30,
        [SubscriptionPlan.QUARTERLY]: 90,
        [SubscriptionPlan.SEMIANNUAL]: 180,
        [SubscriptionPlan.ANNUAL]: 365
      }[plan] ?? 30
    );
  }

  private getPlanUsageLabel(plan: SubscriptionPlan): string {
    return (
      {
        [SubscriptionPlan.MONTHLY]: 'Mensal (30 dias)',
        [SubscriptionPlan.QUARTERLY]: 'Trimestral (90 dias)',
        [SubscriptionPlan.SEMIANNUAL]: 'Semestral (180 dias)',
        [SubscriptionPlan.ANNUAL]: 'Anual (365 dias)'
      }[plan] ?? 'Mensal (30 dias)'
    );
  }

  private addDays(baseDate: Date, days: number): Date {
    return new Date(baseDate.getTime() + days * 24 * 60 * 60 * 1000);
  }

  private assertAgentKey(agentKey?: string): void {
    const expectedKey = (process.env.AGENT_VALIDATION_KEY ?? '').trim();
    if (!expectedKey) {
      throw new UnauthorizedException(
        'AGENT_VALIDATION_KEY is not configured on server.'
      );
    }

    if (!agentKey || agentKey.trim() !== expectedKey) {
      throw new UnauthorizedException('Invalid agent key.');
    }
  }
}
