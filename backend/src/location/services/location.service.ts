import { Injectable } from '@nestjs/common';
import { GeoPoint } from '../../common/interfaces/geo-point.interface';
import { calculateDistanceInKm } from '../../common/utils/distance.util';
import { LocationStore, UserLocationRecord } from '../store/location.store';

export interface NearbyDriver {
  driverId: string;
  coordinates: GeoPoint;
  distanceKm: number;
  updatedAt: Date;
}

@Injectable()
export class LocationService {
  constructor(private readonly locationStore: LocationStore) {}

  updateMyLocation(userId: string, coordinates: GeoPoint): UserLocationRecord {
    return this.locationStore.upsert(userId, coordinates);
  }

  getMyLocation(userId: string): UserLocationRecord | undefined {
    return this.locationStore.findByUserId(userId);
  }

  findNearbyDrivers(input: {
    origin: GeoPoint;
    candidateDriverIds: string[];
    radiusKm: number;
    excludedDriverIds?: string[];
  }): NearbyDriver[] {
    const excluded = new Set(input.excludedDriverIds ?? []);

    return input.candidateDriverIds
      .filter((driverId) => !excluded.has(driverId))
      .map((driverId) => {
        const location = this.locationStore.findByUserId(driverId);
        if (!location) {
          return undefined;
        }

        const distanceKm = calculateDistanceInKm(input.origin, location.coordinates);
        if (distanceKm > input.radiusKm) {
          return undefined;
        }

        return {
          driverId,
          coordinates: location.coordinates,
          distanceKm,
          updatedAt: location.updatedAt
        } satisfies NearbyDriver;
      })
      .filter((item): item is NearbyDriver => Boolean(item))
      .sort((a, b) => a.distanceKm - b.distanceKm);
  }
}
