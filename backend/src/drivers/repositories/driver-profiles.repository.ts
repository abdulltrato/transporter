import { Injectable } from '@nestjs/common';
import { DriverStatus } from '../../common/enums/driver-status.enum';
import { DriverProfileEntity } from '../entities/driver-profile.entity';

@Injectable()
export class DriverProfilesRepository {
  private readonly profiles = new Map<string, DriverProfileEntity>();

  create(userId: string): DriverProfileEntity {
    const now = new Date();
    const profile: DriverProfileEntity = {
      userId,
      status: DriverStatus.OFFLINE,
      createdAt: now,
      updatedAt: now
    };

    this.profiles.set(userId, profile);
    return profile;
  }

  findByUserId(userId: string): DriverProfileEntity | undefined {
    return this.profiles.get(userId);
  }

  save(profile: DriverProfileEntity): DriverProfileEntity {
    this.profiles.set(profile.userId, profile);
    return profile;
  }

  listAll(): DriverProfileEntity[] {
    return Array.from(this.profiles.values());
  }
}
