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

  async updateMyLocation(
    userId: string,
    coordinates: GeoPoint
  ): Promise<UserLocationRecord> {
    return this.locationStore.upsert(userId, coordinates);
  }

  async getMyLocation(userId: string): Promise<UserLocationRecord | undefined> {
    return this.locationStore.findByUserId(userId);
  }

  async findNearbyDrivers(input: {
    origin: GeoPoint;
    candidateDriverIds: string[];
    radiusKm: number;
    excludedDriverIds?: string[];
  }): Promise<NearbyDriver[]> {
    const excluded = new Set(input.excludedDriverIds ?? []);
    const candidateDriverIds = input.candidateDriverIds.filter(
      (driverId) => !excluded.has(driverId)
    );
    const locations = await this.locationStore.listByUserIds(candidateDriverIds);
    const locationByDriverId = new Map(
      locations.map((location) => [location.userId, location])
    );

    return candidateDriverIds
      .map((driverId) => {
        const location = locationByDriverId.get(driverId);
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
