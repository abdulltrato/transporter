import { randomUUID } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { RedisService } from '../../redis/services/redis.service';

export interface OtpRecord {
  requestId: string;
  phone: string;
  codeHash: string;
  expiresAt: Date;
  attempts: number;
  requestCount: number;
  requestWindowStartedAt: Date;
  lastIssuedAt: Date;
}

@Injectable()
export class OtpStore {
  private readonly keyPrefix = 'transporter:auth:otp:';

  constructor(private readonly redisService: RedisService) {}

  async upsert(record: OtpRecord): Promise<void> {
    const key = this.getKey(record.phone);
    const ttlSeconds = Math.max(
      1,
      Math.floor((record.expiresAt.getTime() - Date.now()) / 1000)
    );

    await this.redisService.getClient().hset(key, {
      requestId: record.requestId,
      phone: record.phone,
      codeHash: record.codeHash,
      expiresAt: record.expiresAt.toISOString(),
      attempts: String(record.attempts),
      requestCount: String(record.requestCount),
      requestWindowStartedAt: record.requestWindowStartedAt.toISOString(),
      lastIssuedAt: record.lastIssuedAt.toISOString()
    });
    await this.redisService.getClient().expire(key, ttlSeconds);
  }

  async findByPhone(phone: string): Promise<OtpRecord | undefined> {
    const key = this.getKey(phone);
    const raw = await this.redisService.getClient().hgetall(key);

    if (!raw.requestId || !raw.phone || !raw.codeHash || !raw.expiresAt) {
      return undefined;
    }

    const attempts = Number(raw.attempts ?? 0);
    const requestCount = Number(raw.requestCount ?? 1);
    const expiresAt = new Date(raw.expiresAt);
    const requestWindowStartedAt = raw.requestWindowStartedAt
      ? new Date(raw.requestWindowStartedAt)
      : new Date(expiresAt.getTime());
    const lastIssuedAt = raw.lastIssuedAt
      ? new Date(raw.lastIssuedAt)
      : new Date(expiresAt.getTime());

    if (
      Number.isNaN(expiresAt.getTime()) ||
      Number.isNaN(requestWindowStartedAt.getTime()) ||
      Number.isNaN(lastIssuedAt.getTime()) ||
      !Number.isFinite(attempts) ||
      !Number.isFinite(requestCount)
    ) {
      return undefined;
    }

    return {
      requestId: raw.requestId,
      phone: raw.phone,
      codeHash: raw.codeHash,
      expiresAt,
      attempts,
      requestCount,
      requestWindowStartedAt,
      lastIssuedAt
    };
  }

  async remove(phone: string): Promise<void> {
    await this.redisService.getClient().del(this.getKey(phone));
  }

  createRequestId(): string {
    return randomUUID();
  }

  private getKey(phone: string): string {
    return `${this.keyPrefix}${phone}`;
  }
}
