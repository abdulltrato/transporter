import { randomUUID } from 'node:crypto';
import { Injectable } from '@nestjs/common';

export interface OtpRecord {
  requestId: string;
  phone: string;
  codeHash: string;
  expiresAt: Date;
  attempts: number;
}

@Injectable()
export class OtpStore {
  private readonly recordsByPhone = new Map<string, OtpRecord>();

  upsert(record: OtpRecord): void {
    this.recordsByPhone.set(record.phone, record);
  }

  findByPhone(phone: string): OtpRecord | undefined {
    return this.recordsByPhone.get(phone);
  }

  remove(phone: string): void {
    this.recordsByPhone.delete(phone);
  }

  createRequestId(): string {
    return randomUUID();
  }
}
