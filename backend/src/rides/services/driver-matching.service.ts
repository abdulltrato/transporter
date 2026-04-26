import { Injectable } from '@nestjs/common';
import { GeoPoint } from '../../common/interfaces/geo-point.interface';
import { DriversService } from '../../drivers/services/drivers.service';
import { LocationService } from '../../location/services/location.service';

export interface MatchResult {
  driverId: string;
  radiusKm: number;
  distanceKm: number;
}

@Injectable()
export class DriverMatchingService {
  private readonly searchRadiiKm = [2, 5, 8, 12];

  constructor(
    private readonly driversService: DriversService,
    private readonly locationService: LocationService
  ) {}

  findClosestDriver(input: {
    pickup: GeoPoint;
    excludedDriverIds?: string[];
  }): MatchResult | undefined {
    const candidates = this.driversService.listOnlineDriverIds();

    for (const radiusKm of this.searchRadiiKm) {
      const nearbyDrivers = this.locationService.findNearbyDrivers({
        origin: input.pickup,
        candidateDriverIds: candidates,
        radiusKm,
        excludedDriverIds: input.excludedDriverIds
      });

      const selected = nearbyDrivers[0];
      if (selected) {
        return {
          driverId: selected.driverId,
          radiusKm,
          distanceKm: selected.distanceKm
        };
      }
    }

    return undefined;
  }
}
