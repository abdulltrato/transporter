import { Body, Controller, Get, Patch } from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequestUser } from '../../common/interfaces/request-user.interface';
import { UpdateDriverProfileDto } from '../dto/update-driver-profile.dto';
import { UpdateDriverStatusDto } from '../dto/update-driver-status.dto';
import { DriversService } from '../services/drivers.service';

@Controller('drivers')
export class DriversController {
  constructor(private readonly driversService: DriversService) {}

  @Get('me/profile')
  getMyProfile(@CurrentUser() currentUser: RequestUser): ReturnType<DriversService['toPublicProfile']> {
    const profile = this.driversService.ensureProfile(currentUser.id);
    return this.driversService.toPublicProfile(profile);
  }

  @Patch('me/profile')
  updateMyProfile(
    @CurrentUser() currentUser: RequestUser,
    @Body() body: UpdateDriverProfileDto
  ): ReturnType<DriversService['toPublicProfile']> {
    const updated = this.driversService.updateProfile(currentUser.id, body);
    return this.driversService.toPublicProfile(updated);
  }

  @Patch('me/status')
  updateStatus(
    @CurrentUser() currentUser: RequestUser,
    @Body() body: UpdateDriverStatusDto
  ): ReturnType<DriversService['toPublicProfile']> {
    const updated = this.driversService.updateStatus(currentUser.id, body.status);
    return this.driversService.toPublicProfile(updated);
  }
}
