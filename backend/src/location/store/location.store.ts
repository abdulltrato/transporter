import { GeoPoint } from '../../common/interfaces/geo-point.interface';
import { Injectable } from '@nestjs/common';

export interface UserLocationRecord {
  userId: string;
  coordinates: GeoPoint;
  updatedAt: Date;
}

@Injectable()
export class LocationStore {
  private readonly locationByUserId = new Map<string, UserLocationRecord>();

  upsert(userId: string, coordinates: GeoPoint): UserLocationRecord {
    const record: UserLocationRecord = {
      userId,
      coordinates,
      updatedAt: new Date()
    };

    this.locationByUserId.set(userId, record);
    return record;
  }

  findByUserId(userId: string): UserLocationRecord | undefined {
    return this.locationByUserId.get(userId);
  }

  listAll(): UserLocationRecord[] {
    return Array.from(this.locationByUserId.values());
  }
}
