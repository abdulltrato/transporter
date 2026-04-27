import { Body, Controller, Get, Headers, Param, Patch, Post } from '@nestjs/common';
import { Public } from '../../common/decorators/public.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequestUser } from '../../common/interfaces/request-user.interface';
import {
  AgentValidateSubscriptionDto
} from '../dto/agent-validate-subscription.dto';
import { RequestSubscriptionPaymentDto } from '../dto/request-subscription-payment.dto';
import { SubscriptionsService } from '../services/subscriptions.service';

@Controller('subscriptions')
export class SubscriptionsController {
  constructor(private readonly subscriptionsService: SubscriptionsService) {}

  @Post('me/payment')
  async requestPayment(
    @CurrentUser() currentUser: RequestUser,
    @Body() body: RequestSubscriptionPaymentDto
  ): Promise<ReturnType<SubscriptionsService['toPublicSubscription']>> {
    const created = await this.subscriptionsService.requestPayment(currentUser, body);
    return this.subscriptionsService.toPublicSubscription(created);
  }

  @Get('me/current')
  async getMyCurrentSubscription(
    @CurrentUser() currentUser: RequestUser
  ): Promise<ReturnType<SubscriptionsService['toPublicSubscription']> | null> {
    const current = await this.subscriptionsService.getMyCurrentSubscription(
      currentUser
    );
    return current ? this.subscriptionsService.toPublicSubscription(current) : null;
  }

  @Get('me/history')
  async listMySubscriptions(
    @CurrentUser() currentUser: RequestUser
  ): Promise<ReturnType<SubscriptionsService['toPublicSubscription']>[]> {
    const items = await this.subscriptionsService.listMySubscriptions(currentUser);
    return items.map((item) => this.subscriptionsService.toPublicSubscription(item));
  }

  @Public()
  @Get('agent/pending')
  async listPendingForAgents(
    @Headers('x-agent-key') agentKey?: string
  ): Promise<ReturnType<SubscriptionsService['toPublicSubscription']>[]> {
    const items = await this.subscriptionsService.listPendingForAgents(agentKey);
    return items.map((item) => this.subscriptionsService.toPublicSubscription(item));
  }

  @Public()
  @Patch('agent/:subscriptionId/validate')
  async validateByAgent(
    @Param('subscriptionId') subscriptionId: string,
    @Body() body: AgentValidateSubscriptionDto,
    @Headers('x-agent-key') agentKey?: string
  ): Promise<ReturnType<SubscriptionsService['toPublicSubscription']>> {
    const updated = await this.subscriptionsService.validateByAgent({
      subscriptionId,
      payload: body,
      agentKey
    });
    return this.subscriptionsService.toPublicSubscription(updated);
  }
}
