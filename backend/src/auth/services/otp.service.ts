import { Injectable, UnauthorizedException } from '@nestjs/common';
import { createHash, randomInt } from 'node:crypto';
import { getOtpTtlSeconds } from '../config/jwt.config';
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
    const code = randomInt(100000, 999999).toString();
    const expiresAt = new Date(Date.now() + getOtpTtlSeconds() * 1000);

    const record: OtpRecord = {
      requestId: this.otpStore.createRequestId(),
      phone,
      codeHash: this.hash(phone, code),
      expiresAt,
      attempts: 0
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

  private isDevModeEnabled(): boolean {
    const raw = process.env.OTP_DEV_MODE ?? 'true';
    return raw.trim().toLowerCase() === 'true';
  }
}
