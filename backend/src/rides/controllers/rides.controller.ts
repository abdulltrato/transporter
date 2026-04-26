import { Body, Controller, Get, Param, Patch, Post } from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequestUser } from '../../common/interfaces/request-user.interface';
import { RequestRideDto } from '../dto/request-ride.dto';
import { RespondRideDto } from '../dto/respond-ride.dto';
import { RidesService } from '../services/rides.service';

@Controller('rides')
export class RidesController {
  constructor(private readonly ridesService: RidesService) {}

  @Post('request')
  async requestRide(
    @CurrentUser() currentUser: RequestUser,
    @Body() body: RequestRideDto
  ): ReturnType<RidesService['requestRide']> {
    return this.ridesService.requestRide(
      currentUser,
      body.pickup,
      body.dropoff
    );
  }

  @Patch(':rideId/respond')
  async respondRide(
    @CurrentUser() currentUser: RequestUser,
    @Param('rideId') rideId: string,
    @Body() body: RespondRideDto
  ): ReturnType<RidesService['respondToRide']> {
    return this.ridesService.respondToRide(currentUser, rideId, body.action);
  }

  @Patch(':rideId/cancel')
  async cancelRide(
    @CurrentUser() currentUser: RequestUser,
    @Param('rideId') rideId: string
  ): ReturnType<RidesService['cancelRide']> {
    return this.ridesService.cancelRide(currentUser, rideId);
  }

  @Get('me')
  async listMyRides(
    @CurrentUser() currentUser: RequestUser
  ): ReturnType<RidesService['listMyRides']> {
    return this.ridesService.listMyRides(currentUser);
  }
}
