import { randomUUID } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/services/database.service';
import { DriverRatingEntity } from '../entities/driver-rating.entity';

export interface UpsertDriverRatingInput {
  rideId: string;
  driverId: string;
  clientId: string;
  stars: number;
}

@Injectable()
export class DriverRatingsRepository {
  constructor(private readonly database: DatabaseService) {}

  async upsert(input: UpsertDriverRatingInput): Promise<DriverRatingEntity> {
    const now = new Date();
    const result = await this.database.query<DriverRatingRow>(
      `
        INSERT INTO driver_ratings (
          id,
          ride_id,
          driver_id,
          client_id,
          stars,
          created_at,
          updated_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        ON CONFLICT (ride_id) DO UPDATE SET
          stars = EXCLUDED.stars,
          updated_at = EXCLUDED.updated_at
        RETURNING
          id,
          ride_id,
          driver_id,
          client_id,
          stars,
          created_at,
          updated_at
      `,
      [
        randomUUID(),
        input.rideId,
        input.driverId,
        input.clientId,
        input.stars,
        now,
        now
      ]
    );

    return this.toEntity(result.rows[0]);
  }

  async findByRideId(rideId: string): Promise<DriverRatingEntity | undefined> {
    const result = await this.database.query<DriverRatingRow>(
      `
        SELECT
          id,
          ride_id,
          driver_id,
          client_id,
          stars,
          created_at,
          updated_at
        FROM driver_ratings
        WHERE ride_id = $1
        LIMIT 1
      `,
      [rideId]
    );

    const row = result.rows[0];
    return row ? this.toEntity(row) : undefined;
  }

  async listByClientId(clientId: string): Promise<DriverRatingEntity[]> {
    const result = await this.database.query<DriverRatingRow>(
      `
        SELECT
          id,
          ride_id,
          driver_id,
          client_id,
          stars,
          created_at,
          updated_at
        FROM driver_ratings
        WHERE client_id = $1
        ORDER BY created_at DESC
      `,
      [clientId]
    );

    return result.rows.map((row) => this.toEntity(row));
  }

  async getDriverSummary(driverId: string): Promise<{
    totalRatings: number;
    averageStars: number;
    star1: number;
    star2: number;
    star3: number;
    star4: number;
    star5: number;
  }> {
    const result = await this.database.query<{
      total_ratings: string;
      average_stars: string | null;
      star_1: string;
      star_2: string;
      star_3: string;
      star_4: string;
      star_5: string;
    }>(
      `
        SELECT
          COUNT(*)::text AS total_ratings,
          AVG(stars)::text AS average_stars,
          COUNT(*) FILTER (WHERE stars = 1)::text AS star_1,
          COUNT(*) FILTER (WHERE stars = 2)::text AS star_2,
          COUNT(*) FILTER (WHERE stars = 3)::text AS star_3,
          COUNT(*) FILTER (WHERE stars = 4)::text AS star_4,
          COUNT(*) FILTER (WHERE stars = 5)::text AS star_5
        FROM driver_ratings
        WHERE driver_id = $1
      `,
      [driverId]
    );

    const row = result.rows[0];
    return {
      totalRatings: Number(row?.total_ratings ?? 0),
      averageStars: Number(row?.average_stars ?? 0),
      star1: Number(row?.star_1 ?? 0),
      star2: Number(row?.star_2 ?? 0),
      star3: Number(row?.star_3 ?? 0),
      star4: Number(row?.star_4 ?? 0),
      star5: Number(row?.star_5 ?? 0)
    };
  }

  private toEntity(row: DriverRatingRow): DriverRatingEntity {
    return {
      id: row.id,
      rideId: row.ride_id,
      driverId: row.driver_id,
      clientId: row.client_id,
      stars: Number(row.stars),
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at)
    };
  }
}

interface DriverRatingRow {
  id: string;
  ride_id: string;
  driver_id: string;
  client_id: string;
  stars: number;
  created_at: Date | string;
  updated_at: Date | string;
}
