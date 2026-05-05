import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { DriversModule } from '../drivers/drivers.module';
import { LocationModule } from '../location/location.module';
import { UsersModule } from '../users/users.module';
import { RealtimeEventsModule } from './events/realtime-events.module';
import { RealtimeGateway } from './gateways/realtime.gateway';

@Module({
  imports: [
    AuthModule,
    DriversModule,
    LocationModule,
    UsersModule,
    RealtimeEventsModule
  ],
  providers: [RealtimeGateway]
})
export class RealtimeModule {}
