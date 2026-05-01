import { Module } from '@nestjs/common';
import { RealtimeEventsModule } from '../realtime/events/realtime-events.module';
import { UsersModule } from '../users/users.module';
import { DriversController } from './controllers/drivers.controller';
import { DriverProfilesRepository } from './repositories/driver-profiles.repository';
import { DriverProfileValidatorService } from './services/driver-profile-validator.service';
import { DriversService } from './services/drivers.service';
import { DriverPresenceStore } from './store/driver-presence.store';

@Module({
  imports: [UsersModule, RealtimeEventsModule],
  controllers: [DriversController],
  providers: [
    DriverProfilesRepository,
    DriverPresenceStore,
    DriverProfileValidatorService,
    DriversService
  ],
  exports: [DriversService]
})
export class DriversModule {}
