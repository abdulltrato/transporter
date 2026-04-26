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
  async getMyProfile(
    @CurrentUser() currentUser: RequestUser
  ): Promise<ReturnType<DriversService['toPublicProfile']>> {
    const profile = await this.driversService.ensureProfile(currentUser.id);
    return this.driversService.toPublicProfile(profile);
  }

  @Patch('me/profile')
  async updateMyProfile(
    @CurrentUser() currentUser: RequestUser,
    @Body() body: UpdateDriverProfileDto
  ): Promise<ReturnType<DriversService['toPublicProfile']>> {
    const updated = await this.driversService.updateProfile(currentUser.id, body);
    return this.driversService.toPublicProfile(updated);
  }

  @Patch('me/status')
  async updateStatus(
    @CurrentUser() currentUser: RequestUser,
    @Body() body: UpdateDriverStatusDto
  ): Promise<ReturnType<DriversService['toPublicProfile']>> {
    const updated = await this.driversService.updateStatus(
      currentUser.id,
      body.status
    );
    return this.driversService.toPublicProfile(updated);
  }
}
