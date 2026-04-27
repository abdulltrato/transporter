import { Module } from '@nestjs/common';
import { SubscriptionsController } from './controllers/subscriptions.controller';
import { DriverSubscriptionsRepository } from './repositories/driver-subscriptions.repository';
import { SubscriptionsService } from './services/subscriptions.service';

@Module({
  controllers: [SubscriptionsController],
  providers: [DriverSubscriptionsRepository, SubscriptionsService],
  exports: [SubscriptionsService]
})
export class SubscriptionsModule {}
