import { BadRequestException, Injectable } from '@nestjs/common';
import { DriverProfileEntity } from '../entities/driver-profile.entity';

@Injectable()
export class DriverProfileValidatorService {
  isProfileComplete(profile: DriverProfileEntity): boolean {
    return Boolean(
      profile.documentId &&
        profile.documentExpiry &&
        profile.neighborhood &&
        profile.operatingRegion
    );
  }

  assertCanGoOnline(profile: DriverProfileEntity): void {
    if (!this.isProfileComplete(profile)) {
      throw new BadRequestException(
        'Driver profile is incomplete. Fill documentId, documentExpiry, neighborhood and operatingRegion before going online.'
      );
    }

    if (profile.documentExpiry && new Date(profile.documentExpiry).getTime() < Date.now()) {
      throw new BadRequestException('Driver document is expired.');
    }
  }
}
