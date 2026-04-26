import { Controller, Get, Put, Body, Query } from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { DriverStatus } from '../../common/enums/driver-status.enum';
import { UserRole } from '../../common/enums/user-role.enum';
import { RequestUser } from '../../common/interfaces/request-user.interface';
import { DriversService } from '../../drivers/services/drivers.service';
import { RealtimeEventsService } from '../../realtime/events/realtime-events.service';
import { NearbyDriversQueryDto } from '../dto/nearby-drivers-query.dto';
import { UpdateMyLocationDto } from '../dto/update-my-location.dto';
import { LocationService } from '../services/location.service';

@Controller('location')
export class LocationController {
  constructor(
    private readonly locationService: LocationService,
    private readonly driversService: DriversService,
    private readonly realtimeEvents: RealtimeEventsService
  ) {}

  @Put('me')
  async updateMyLocation(
    @CurrentUser() currentUser: RequestUser,
    @Body() body: UpdateMyLocationDto
  ): ReturnType<LocationService['updateMyLocation']> {
    const updatedLocation = await this.locationService.updateMyLocation(currentUser.id, {
      lat: body.lat,
      lng: body.lng
    });

    if (currentUser.role === UserRole.DRIVER) {
      const profile = await this.driversService.ensureProfile(currentUser.id);

      if (profile.status === DriverStatus.ONLINE) {
        this.realtimeEvents.emitDriverLocationUpdated({
          driverId: currentUser.id,
          coordinates: updatedLocation.coordinates,
          updatedAt: updatedLocation.updatedAt.toISOString()
        });
      }
    }

    return updatedLocation;
  }

  @Get('me')
  getMyLocation(
    @CurrentUser() currentUser: RequestUser
  ): ReturnType<LocationService['getMyLocation']> {
    return this.locationService.getMyLocation(currentUser.id);
  }

  @Get('drivers/nearby')
  async getNearbyDrivers(
    @Query() query: NearbyDriversQueryDto
  ): ReturnType<LocationService['findNearbyDrivers']> {
    const candidateDriverIds = await this.driversService.listOnlineDriverIds();

    return this.locationService.findNearbyDrivers({
      origin: { lat: query.lat, lng: query.lng },
      radiusKm: query.radiusKm,
      candidateDriverIds
    });
  }
}
