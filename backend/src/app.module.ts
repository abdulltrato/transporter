import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { AuthModule } from './auth/auth.module';
import { AuthGuard } from './common/guards/auth.guard';
import { DriversModule } from './drivers/drivers.module';
import { LocationModule } from './location/location.module';
import { RidesModule } from './rides/rides.module';
import { UsersModule } from './users/users.module';

@Module({
  imports: [AuthModule, UsersModule, DriversModule, LocationModule, RidesModule],
  providers: [
    {
      provide: APP_GUARD,
      useClass: AuthGuard
    }
  ]
})
export class AppModule {}
