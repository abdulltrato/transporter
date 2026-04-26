import { Injectable } from '@nestjs/common';
import { GeoPoint } from '../../common/interfaces/geo-point.interface';
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
    const candidateDriverIdSet = new Set(candidateDriverIds);

    if (candidateDriverIdSet.size === 0) {
      return [];
    }

    const nearbyByGeo = await this.locationStore.searchNearbyByRadius(
      input.origin,
      input.radiusKm
    );
    const filteredNearby = nearbyByGeo.filter((driver) =>
      candidateDriverIdSet.has(driver.userId)
    );

    if (filteredNearby.length === 0) {
      return [];
    }

    const locations = await this.locationStore.listByUserIds(
      filteredNearby.map((driver) => driver.userId)
    );
    const locationByDriverId = new Map(
      locations.map((location) => [location.userId, location])
    );

    const staleDriverIds: string[] = [];
    const nearbyDrivers = filteredNearby
      .map((candidate) => {
        const location = locationByDriverId.get(candidate.userId);
        if (!location) {
          staleDriverIds.push(candidate.userId);
          return undefined;
        }

        return {
          driverId: candidate.userId,
          coordinates: location.coordinates,
          distanceKm: candidate.distanceKm,
          updatedAt: location.updatedAt
        } satisfies NearbyDriver;
      })
      .filter((item): item is NearbyDriver => Boolean(item));

    if (staleDriverIds.length > 0) {
      await this.locationStore.removeManyFromGeoIndex(staleDriverIds);
    }

    return nearbyDrivers;
  }
}
