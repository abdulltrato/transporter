import { GeoPoint } from '../../common/interfaces/geo-point.interface';
import { Injectable } from '@nestjs/common';
import { RedisService } from '../../redis/services/redis.service';

export interface UserLocationRecord {
  userId: string;
  coordinates: GeoPoint;
  updatedAt: Date;
}

export interface GeoSearchResult {
  userId: string;
  distanceKm: number;
}

@Injectable()
export class LocationStore {
  private readonly keyPrefix = 'transporter:location:';
  private readonly geoIndexKey = 'transporter:location:geo';
  private readonly defaultTtlSeconds = Number(
    process.env.LOCATION_TTL_SECONDS ?? 1800
  );

  constructor(private readonly redisService: RedisService) {}

  async upsert(userId: string, coordinates: GeoPoint): Promise<UserLocationRecord> {
    const record: UserLocationRecord = {
      userId,
      coordinates,
      updatedAt: new Date()
    };

    const key = this.getKey(userId);
    const pipeline = this.redisService.getClient().pipeline();
    pipeline.hset(key, {
      lat: String(coordinates.lat),
      lng: String(coordinates.lng),
      updatedAt: record.updatedAt.toISOString()
    });

    if (this.defaultTtlSeconds > 0) {
      pipeline.expire(key, this.defaultTtlSeconds);
    }

    pipeline.geoadd(
      this.geoIndexKey,
      coordinates.lng,
      coordinates.lat,
      userId
    );
    await pipeline.exec();

    return record;
  }

  async findByUserId(userId: string): Promise<UserLocationRecord | undefined> {
    const key = this.getKey(userId);
    const raw = await this.redisService.getClient().hgetall(key);

    return this.toRecord(userId, raw);
  }

  async listByUserIds(userIds: string[]): Promise<UserLocationRecord[]> {
    if (userIds.length === 0) {
      return [];
    }

    const pipeline = this.redisService.getClient().pipeline();
    for (const userId of userIds) {
      pipeline.hgetall(this.getKey(userId));
    }

    const results = await pipeline.exec();
    if (!results) {
      return [];
    }

    return results
      .map(([error, rawRecord], index) => {
        if (error) {
          return undefined;
        }

        const userId = userIds[index];
        return this.toRecord(userId, rawRecord as Record<string, string>);
      })
      .filter((item): item is UserLocationRecord => Boolean(item));
  }

  async searchNearbyByRadius(
    origin: GeoPoint,
    radiusKm: number
  ): Promise<GeoSearchResult[]> {
    const rawResults = await this.redisService.getClient().call(
      'GEOSEARCH',
      this.geoIndexKey,
      'FROMLONLAT',
      String(origin.lng),
      String(origin.lat),
      'BYRADIUS',
      String(radiusKm),
      'km',
      'WITHDIST',
      'ASC'
    );

    if (!Array.isArray(rawResults)) {
      return [];
    }

    return rawResults
      .map((rawResult) => this.toGeoSearchResult(rawResult))
      .filter((item): item is GeoSearchResult => Boolean(item));
  }

  async removeManyFromGeoIndex(userIds: string[]): Promise<void> {
    if (userIds.length === 0) {
      return;
    }

    await this.redisService.getClient().zrem(this.geoIndexKey, ...userIds);
  }

  private getKey(userId: string): string {
    return `${this.keyPrefix}${userId}`;
  }

  private toRecord(
    userId: string,
    raw: Record<string, string>
  ): UserLocationRecord | undefined {
    if (!raw.lat || !raw.lng || !raw.updatedAt) {
      return undefined;
    }

    const lat = Number(raw.lat);
    const lng = Number(raw.lng);
    const updatedAt = new Date(raw.updatedAt);

    if (!Number.isFinite(lat) || !Number.isFinite(lng) || Number.isNaN(updatedAt.getTime())) {
      return undefined;
    }

    return {
      userId,
      coordinates: { lat, lng },
      updatedAt
    };
  }

  private toGeoSearchResult(rawResult: unknown): GeoSearchResult | undefined {
    if (!Array.isArray(rawResult) || rawResult.length < 2) {
      return undefined;
    }

    const userId = this.toString(rawResult[0]);
    const distanceKm = Number(this.toString(rawResult[1]));

    if (!userId || !Number.isFinite(distanceKm)) {
      return undefined;
    }

    return { userId, distanceKm };
  }

  private toString(value: unknown): string {
    if (typeof value === 'string') {
      return value;
    }

    if (Buffer.isBuffer(value)) {
      return value.toString('utf8');
    }

    return String(value);
  }
}
