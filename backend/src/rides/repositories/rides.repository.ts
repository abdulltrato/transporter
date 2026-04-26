import { randomUUID } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { RideStatus } from '../../common/enums/ride-status.enum';
import { DatabaseService } from '../../database/services/database.service';
import { GeoPoint } from '../../common/interfaces/geo-point.interface';
import { RideEntity } from '../entities/ride.entity';

export interface CreateRideInput {
  clientId: string;
  pickup: GeoPoint;
  dropoff?: GeoPoint;
  status: RideStatus;
  driverId?: string;
  searchRadiusKm?: number;
  rejectedDriverIds?: string[];
}

@Injectable()
export class RidesRepository {
  constructor(private readonly database: DatabaseService) {}

  async create(input: CreateRideInput): Promise<RideEntity> {
    const now = new Date();
    const result = await this.database.query<RideRow>(
      `
        INSERT INTO rides (
          id,
          client_id,
          driver_id,
          pickup_lat,
          pickup_lng,
          dropoff_lat,
          dropoff_lng,
          status,
          search_radius_km,
          rejected_driver_ids,
          created_at,
          updated_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
        RETURNING
          id,
          client_id,
          driver_id,
          pickup_lat,
          pickup_lng,
          dropoff_lat,
          dropoff_lng,
          status,
          search_radius_km,
          rejected_driver_ids,
          created_at,
          updated_at
      `,
      [
        randomUUID(),
        input.clientId,
        input.driverId ?? null,
        input.pickup.lat,
        input.pickup.lng,
        input.dropoff?.lat ?? null,
        input.dropoff?.lng ?? null,
        input.status,
        input.searchRadiusKm ?? null,
        input.rejectedDriverIds ?? [],
        now,
        now
      ]
    );

    return this.toEntity(result.rows[0]);
  }

  async findById(rideId: string): Promise<RideEntity | undefined> {
    const result = await this.database.query<RideRow>(
      `
        SELECT
          id,
          client_id,
          driver_id,
          pickup_lat,
          pickup_lng,
          dropoff_lat,
          dropoff_lng,
          status,
          search_radius_km,
          rejected_driver_ids,
          created_at,
          updated_at
        FROM rides
        WHERE id = $1
        LIMIT 1
      `,
      [rideId]
    );

    const row = result.rows[0];
    return row ? this.toEntity(row) : undefined;
  }

  async save(ride: RideEntity): Promise<RideEntity> {
    const updatedAt = new Date();
    const result = await this.database.query<RideRow>(
      `
        INSERT INTO rides (
          id,
          client_id,
          driver_id,
          pickup_lat,
          pickup_lng,
          dropoff_lat,
          dropoff_lng,
          status,
          search_radius_km,
          rejected_driver_ids,
          created_at,
          updated_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
        ON CONFLICT (id) DO UPDATE SET
          client_id = EXCLUDED.client_id,
          driver_id = EXCLUDED.driver_id,
          pickup_lat = EXCLUDED.pickup_lat,
          pickup_lng = EXCLUDED.pickup_lng,
          dropoff_lat = EXCLUDED.dropoff_lat,
          dropoff_lng = EXCLUDED.dropoff_lng,
          status = EXCLUDED.status,
          search_radius_km = EXCLUDED.search_radius_km,
          rejected_driver_ids = EXCLUDED.rejected_driver_ids,
          updated_at = EXCLUDED.updated_at
        RETURNING
          id,
          client_id,
          driver_id,
          pickup_lat,
          pickup_lng,
          dropoff_lat,
          dropoff_lng,
          status,
          search_radius_km,
          rejected_driver_ids,
          created_at,
          updated_at
      `,
      [
        ride.id,
        ride.clientId,
        ride.driverId ?? null,
        ride.pickup.lat,
        ride.pickup.lng,
        ride.dropoff?.lat ?? null,
        ride.dropoff?.lng ?? null,
        ride.status,
        ride.searchRadiusKm ?? null,
        ride.rejectedDriverIds,
        ride.createdAt,
        updatedAt
      ]
    );

    return this.toEntity(result.rows[0]);
  }

  async listByClientId(clientId: string): Promise<RideEntity[]> {
    const result = await this.database.query<RideRow>(
      `
        SELECT
          id,
          client_id,
          driver_id,
          pickup_lat,
          pickup_lng,
          dropoff_lat,
          dropoff_lng,
          status,
          search_radius_km,
          rejected_driver_ids,
          created_at,
          updated_at
        FROM rides
        WHERE client_id = $1
        ORDER BY created_at DESC
      `,
      [clientId]
    );

    return result.rows.map((row) => this.toEntity(row));
  }

  async listByDriverId(driverId: string): Promise<RideEntity[]> {
    const result = await this.database.query<RideRow>(
      `
        SELECT
          id,
          client_id,
          driver_id,
          pickup_lat,
          pickup_lng,
          dropoff_lat,
          dropoff_lng,
          status,
          search_radius_km,
          rejected_driver_ids,
          created_at,
          updated_at
        FROM rides
        WHERE driver_id = $1
        ORDER BY created_at DESC
      `,
      [driverId]
    );

    return result.rows.map((row) => this.toEntity(row));
  }

  private toEntity(row: RideRow): RideEntity {
    const hasDropoff = row.dropoff_lat !== null && row.dropoff_lng !== null;

    return {
      id: row.id,
      clientId: row.client_id,
      driverId: row.driver_id ?? undefined,
      pickup: {
        lat: Number(row.pickup_lat),
        lng: Number(row.pickup_lng)
      },
      dropoff: hasDropoff
        ? {
            lat: Number(row.dropoff_lat),
            lng: Number(row.dropoff_lng)
          }
        : undefined,
      status: row.status,
      searchRadiusKm:
        row.search_radius_km === null ? undefined : Number(row.search_radius_km),
      rejectedDriverIds: row.rejected_driver_ids ?? [],
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at)
    };
  }
}

interface RideRow {
  id: string;
  client_id: string;
  driver_id: string | null;
  pickup_lat: number;
  pickup_lng: number;
  dropoff_lat: number | null;
  dropoff_lng: number | null;
  status: RideStatus;
  search_radius_km: number | null;
  rejected_driver_ids: string[];
  created_at: Date | string;
  updated_at: Date | string;
}
