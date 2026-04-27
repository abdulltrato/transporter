import { Module } from '@nestjs/common';
import { RidesModule } from '../rides/rides.module';
import { RatingsController } from './controllers/ratings.controller';
import { DriverRatingsRepository } from './repositories/driver-ratings.repository';
import { RatingsService } from './services/ratings.service';

@Module({
  imports: [RidesModule],
  controllers: [RatingsController],
  providers: [DriverRatingsRepository, RatingsService],
  exports: [RatingsService]
})
export class RatingsModule {}
