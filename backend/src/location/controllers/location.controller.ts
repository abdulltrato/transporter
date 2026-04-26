import { Controller, Get, Put, Body, Query } from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequestUser } from '../../common/interfaces/request-user.interface';
import { DriversService } from '../../drivers/services/drivers.service';
import { NearbyDriversQueryDto } from '../dto/nearby-drivers-query.dto';
import { UpdateMyLocationDto } from '../dto/update-my-location.dto';
import { LocationService } from '../services/location.service';

@Controller('location')
export class LocationController {
  constructor(
    private readonly locationService: LocationService,
    private readonly driversService: DriversService
  ) {}

  @Put('me')
  updateMyLocation(
    @CurrentUser() currentUser: RequestUser,
    @Body() body: UpdateMyLocationDto
  ): ReturnType<LocationService['updateMyLocation']> {
    return this.locationService.updateMyLocation(currentUser.id, {
      lat: body.lat,
      lng: body.lng
    });
  }

  @Get('me')
  getMyLocation(
    @CurrentUser() currentUser: RequestUser
  ): ReturnType<LocationService['getMyLocation']> {
    return this.locationService.getMyLocation(currentUser.id);
  }

  @Get('drivers/nearby')
  getNearbyDrivers(@Query() query: NearbyDriversQueryDto): ReturnType<LocationService['findNearbyDrivers']> {
    return this.locationService.findNearbyDrivers({
      origin: { lat: query.lat, lng: query.lng },
      radiusKm: query.radiusKm,
      candidateDriverIds: this.driversService.listOnlineDriverIds()
    });
  }
}
