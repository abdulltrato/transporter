import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { AuthModule } from './auth/auth.module';
import { AuthGuard } from './common/guards/auth.guard';
import { DatabaseModule } from './database/database.module';
import { DriversModule } from './drivers/drivers.module';
import { LocationModule } from './location/location.module';
import { RedisModule } from './redis/redis.module';
import { RatingsModule } from './ratings/ratings.module';
import { RealtimeModule } from './realtime/realtime.module';
import { RidesModule } from './rides/rides.module';
import { SubscriptionsModule } from './subscriptions/subscriptions.module';
import { UsersModule } from './users/users.module';

@Module({
  imports: [
    DatabaseModule,
    RedisModule,
    AuthModule,
    UsersModule,
    DriversModule,
    SubscriptionsModule,
    RatingsModule,
    LocationModule,
    RealtimeModule,
    RidesModule
  ],
  providers: [
    {
      provide: APP_GUARD,
      useClass: AuthGuard
    }
  ]
})
export class AppModule {}
