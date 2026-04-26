import {
  Injectable,
  Logger,
  OnApplicationShutdown,
  OnModuleInit
} from '@nestjs/common';
import { Pool, QueryResult, QueryResultRow } from 'pg';

@Injectable()
export class DatabaseService
  implements OnModuleInit, OnApplicationShutdown
{
  private readonly logger = new Logger(DatabaseService.name);

  private readonly pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    host: process.env.DATABASE_URL
      ? undefined
      : process.env.POSTGRES_HOST ?? 'localhost',
    port: process.env.DATABASE_URL
      ? undefined
      : Number(process.env.POSTGRES_PORT ?? 5432),
    user: process.env.DATABASE_URL
      ? undefined
      : process.env.POSTGRES_USER ?? 'postgres',
    password: process.env.DATABASE_URL
      ? undefined
      : process.env.POSTGRES_PASSWORD ?? 'postgres',
    database: process.env.DATABASE_URL
      ? undefined
      : process.env.POSTGRES_DB ?? 'transporter'
  });

  async onModuleInit(): Promise<void> {
    await this.pool.query('SELECT 1');
    await this.ensureSchema();
    this.logger.log('PostgreSQL connection initialized.');
  }

  async onApplicationShutdown(): Promise<void> {
    await this.pool.end();
  }

  async query<T extends QueryResultRow>(
    text: string,
    params: unknown[] = []
  ): Promise<QueryResult<T>> {
    return this.pool.query<T>(text, params);
  }

  private async ensureSchema(): Promise<void> {
    await this.pool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id UUID PRIMARY KEY,
        full_name TEXT NOT NULL,
        phone TEXT NOT NULL UNIQUE,
        role TEXT NOT NULL CHECK (role IN ('driver', 'client')),
        created_at TIMESTAMPTZ NOT NULL,
        updated_at TIMESTAMPTZ NOT NULL
      );

      CREATE TABLE IF NOT EXISTS driver_profiles (
        user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        document_id TEXT,
        document_expiry TEXT,
        neighborhood TEXT,
        operating_region TEXT,
        status TEXT NOT NULL CHECK (status IN ('online', 'offline')),
        created_at TIMESTAMPTZ NOT NULL,
        updated_at TIMESTAMPTZ NOT NULL
      );

      CREATE INDEX IF NOT EXISTS idx_driver_profiles_status ON driver_profiles(status);

      CREATE TABLE IF NOT EXISTS rides (
        id UUID PRIMARY KEY,
        client_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        driver_id UUID REFERENCES users(id) ON DELETE SET NULL,
        pickup_lat DOUBLE PRECISION NOT NULL,
        pickup_lng DOUBLE PRECISION NOT NULL,
        dropoff_lat DOUBLE PRECISION,
        dropoff_lng DOUBLE PRECISION,
        status TEXT NOT NULL CHECK (
          status IN ('searching', 'assigned', 'accepted', 'rejected', 'cancelled', 'completed')
        ),
        search_radius_km DOUBLE PRECISION,
        rejected_driver_ids TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
        created_at TIMESTAMPTZ NOT NULL,
        updated_at TIMESTAMPTZ NOT NULL
      );

      CREATE INDEX IF NOT EXISTS idx_rides_client_created_at
        ON rides(client_id, created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_rides_driver_created_at
        ON rides(driver_id, created_at DESC);
    `);
  }
}
