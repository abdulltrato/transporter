import { Module } from '@nestjs/common';
import { DriversModule } from '../drivers/drivers.module';
import { LocationController } from './controllers/location.controller';
import { LocationService } from './services/location.service';
import { LocationStore } from './store/location.store';

@Module({
  imports: [DriversModule],
  controllers: [LocationController],
  providers: [LocationStore, LocationService],
  exports: [LocationService]
})
export class LocationModule {}
