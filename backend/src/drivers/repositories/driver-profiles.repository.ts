import { Injectable } from '@nestjs/common';
import { DriverStatus } from '../../common/enums/driver-status.enum';
import { DatabaseService } from '../../database/services/database.service';
import { DriverProfileEntity } from '../entities/driver-profile.entity';

@Injectable()
export class DriverProfilesRepository {
  constructor(private readonly database: DatabaseService) {}

  async create(userId: string): Promise<DriverProfileEntity> {
    const now = new Date();
    const createResult = await this.database.query<DriverProfileRow>(
      `
        INSERT INTO driver_profiles (
          user_id,
          status,
          created_at,
          updated_at
        )
        VALUES ($1, $2, $3, $4)
        ON CONFLICT (user_id) DO NOTHING
        RETURNING
          user_id,
          document_id,
          document_expiry,
          neighborhood,
          operating_region,
          status,
          created_at,
          updated_at
      `,
      [userId, DriverStatus.OFFLINE, now, now]
    );

    const created = createResult.rows[0];
    if (created) {
      return this.toEntity(created);
    }

    const existing = await this.findByUserId(userId);
    if (!existing) {
      throw new Error('Failed to create or load driver profile.');
    }

    return existing;
  }

  async findByUserId(userId: string): Promise<DriverProfileEntity | undefined> {
    const result = await this.database.query<DriverProfileRow>(
      `
        SELECT
          user_id,
          document_id,
          document_expiry,
          neighborhood,
          operating_region,
          status,
          created_at,
          updated_at
        FROM driver_profiles
        WHERE user_id = $1
        LIMIT 1
      `,
      [userId]
    );

    const row = result.rows[0];
    return row ? this.toEntity(row) : undefined;
  }

  async save(profile: DriverProfileEntity): Promise<DriverProfileEntity> {
    const result = await this.database.query<DriverProfileRow>(
      `
        INSERT INTO driver_profiles (
          user_id,
          document_id,
          document_expiry,
          neighborhood,
          operating_region,
          status,
          created_at,
          updated_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        ON CONFLICT (user_id) DO UPDATE SET
          document_id = EXCLUDED.document_id,
          document_expiry = EXCLUDED.document_expiry,
          neighborhood = EXCLUDED.neighborhood,
          operating_region = EXCLUDED.operating_region,
          status = EXCLUDED.status,
          updated_at = EXCLUDED.updated_at
        RETURNING
          user_id,
          document_id,
          document_expiry,
          neighborhood,
          operating_region,
          status,
          created_at,
          updated_at
      `,
      [
        profile.userId,
        profile.documentId ?? null,
        profile.documentExpiry ?? null,
        profile.neighborhood ?? null,
        profile.operatingRegion ?? null,
        profile.status,
        profile.createdAt,
        profile.updatedAt
      ]
    );

    return this.toEntity(result.rows[0]);
  }

  async listAll(): Promise<DriverProfileEntity[]> {
    const result = await this.database.query<DriverProfileRow>(
      `
        SELECT
          user_id,
          document_id,
          document_expiry,
          neighborhood,
          operating_region,
          status,
          created_at,
          updated_at
        FROM driver_profiles
      `
    );

    return result.rows.map((row) => this.toEntity(row));
  }

  private toEntity(row: DriverProfileRow): DriverProfileEntity {
    return {
      userId: row.user_id,
      documentId: row.document_id ?? undefined,
      documentExpiry: row.document_expiry ?? undefined,
      neighborhood: row.neighborhood ?? undefined,
      operatingRegion: row.operating_region ?? undefined,
      status: row.status,
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at)
    };
  }
}

interface DriverProfileRow {
  user_id: string;
  document_id: string | null;
  document_expiry: string | null;
  neighborhood: string | null;
  operating_region: string | null;
  status: DriverStatus;
  created_at: Date | string;
  updated_at: Date | string;
}
