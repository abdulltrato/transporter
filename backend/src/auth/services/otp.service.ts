import {
  HttpException,
  HttpStatus,
  Injectable,
  UnauthorizedException
} from '@nestjs/common';
import { createHash, randomInt } from 'node:crypto';
import {
  getOtpMaxRequestsPerWindow,
  getOtpRequestCooldownSeconds,
  getOtpRequestWindowSeconds,
  getOtpTtlSeconds
} from '../config/jwt.config';
import { OtpRecord, OtpStore } from '../store/otp.store';

export interface IssuedOtp {
  requestId: string;
  expiresAt: Date;
  devCode?: string;
}

@Injectable()
export class OtpService {
  constructor(private readonly otpStore: OtpStore) {}

  async issue(phone: string): Promise<IssuedOtp> {
    const existing = await this.otpStore.findByPhone(phone);
    const nowMs = Date.now();
    const cooldownSeconds = getOtpRequestCooldownSeconds();
    const windowSeconds = getOtpRequestWindowSeconds();
    const maxRequests = getOtpMaxRequestsPerWindow();

    const normalizedLastIssuedAt = existing
      ? this.normalizeDate(existing.lastIssuedAt, nowMs)
      : undefined;
    const normalizedWindowStart = existing
      ? this.normalizeDate(existing.requestWindowStartedAt, nowMs)
      : undefined;

    if (normalizedLastIssuedAt) {
      const elapsedSeconds = Math.floor(
        (nowMs - normalizedLastIssuedAt.getTime()) / 1000
      );
      const retryAfterSeconds = cooldownSeconds - elapsedSeconds;

      if (retryAfterSeconds > 0) {
        throw new HttpException(
          `OTP was requested too recently. Try again in ${retryAfterSeconds} seconds.`,
          HttpStatus.TOO_MANY_REQUESTS
        );
      }
    }

    const windowStart = normalizedWindowStart ?? new Date(nowMs);
    const windowElapsedSeconds = Math.floor(
      (nowMs - windowStart.getTime()) / 1000
    );
    const hasWindowExpired = windowElapsedSeconds >= windowSeconds;
    const requestCount = hasWindowExpired
      ? 0
      : Math.max(0, existing?.requestCount ?? 0);

    if (requestCount >= maxRequests) {
      const retryAfterSeconds = Math.max(1, windowSeconds - windowElapsedSeconds);
      throw new HttpException(
        `OTP request limit reached. Try again in ${retryAfterSeconds} seconds.`,
        HttpStatus.TOO_MANY_REQUESTS
      );
    }

    const code = randomInt(100000, 999999).toString();
    const expiresAt = new Date(Date.now() + getOtpTtlSeconds() * 1000);

    const record: OtpRecord = {
      requestId: this.otpStore.createRequestId(),
      phone,
      codeHash: this.hash(phone, code),
      expiresAt,
      attempts: 0,
      requestCount: requestCount + 1,
      requestWindowStartedAt: hasWindowExpired ? new Date(nowMs) : windowStart,
      lastIssuedAt: new Date(nowMs)
    };

    await this.otpStore.upsert(record);

    const issued: IssuedOtp = {
      requestId: record.requestId,
      expiresAt: record.expiresAt
    };

    if (this.isDevModeEnabled()) {
      issued.devCode = code;
    }

    return issued;
  }

  async validate(phone: string, code: string): Promise<void> {
    const record = await this.otpStore.findByPhone(phone);

    if (!record) {
      throw new UnauthorizedException('OTP not requested for this phone number.');
    }

    if (record.expiresAt.getTime() < Date.now()) {
      await this.otpStore.remove(phone);
      throw new UnauthorizedException('OTP expired. Request a new code.');
    }

    if (record.attempts >= 5) {
      await this.otpStore.remove(phone);
      throw new UnauthorizedException('OTP retry limit reached. Request a new code.');
    }

    record.attempts += 1;
    const isValid = record.codeHash === this.hash(phone, code);

    if (!isValid) {
      await this.otpStore.upsert(record);
      throw new UnauthorizedException('Invalid OTP code.');
    }

    await this.otpStore.remove(phone);
  }

  private hash(phone: string, code: string): string {
    return createHash('sha256').update(`${phone}:${code}`).digest('hex');
  }

  private normalizeDate(input: Date, fallbackNowMs: number): Date {
    if (Number.isNaN(input.getTime())) {
      return new Date(fallbackNowMs);
    }

    if (input.getTime() > fallbackNowMs) {
      return new Date(fallbackNowMs);
    }

    return input;
  }

  private isDevModeEnabled(): boolean {
    const raw = process.env.OTP_DEV_MODE ?? 'true';
    return raw.trim().toLowerCase() === 'true';
  }
}
