import { Module } from '@nestjs/common';
import { UsersModule } from '../users/users.module';
import { DriversController } from './controllers/drivers.controller';
import { DriverProfilesRepository } from './repositories/driver-profiles.repository';
import { DriverProfileValidatorService } from './services/driver-profile-validator.service';
import { DriversService } from './services/drivers.service';

@Module({
  imports: [UsersModule],
  controllers: [DriversController],
  providers: [DriverProfilesRepository, DriverProfileValidatorService, DriversService],
  exports: [DriversService]
})
export class DriversModule {}
