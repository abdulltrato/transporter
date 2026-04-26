import { randomUUID } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { RedisService } from '../../redis/services/redis.service';

export interface OtpRecord {
  requestId: string;
  phone: string;
  codeHash: string;
  expiresAt: Date;
  attempts: number;
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
      attempts: String(record.attempts)
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
    const expiresAt = new Date(raw.expiresAt);
    if (Number.isNaN(expiresAt.getTime()) || !Number.isFinite(attempts)) {
      return undefined;
    }

    return {
      requestId: raw.requestId,
      phone: raw.phone,
      codeHash: raw.codeHash,
      expiresAt,
      attempts
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
