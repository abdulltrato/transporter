import { Module } from '@nestjs/common';
import { DriversModule } from '../drivers/drivers.module';
import { LocationModule } from '../location/location.module';
import { RealtimeEventsModule } from '../realtime/events/realtime-events.module';
import { RidesController } from './controllers/rides.controller';
import { RidesRepository } from './repositories/rides.repository';
import { DriverMatchingService } from './services/driver-matching.service';
import { RidesService } from './services/rides.service';

@Module({
  imports: [DriversModule, LocationModule, RealtimeEventsModule],
  controllers: [RidesController],
  providers: [RidesRepository, DriverMatchingService, RidesService],
  exports: [RidesService]
})
export class RidesModule {}
