import {
  ForbiddenException,
  Injectable,
  NotFoundException
} from '@nestjs/common';
import { DriverStatus } from '../../common/enums/driver-status.enum';
import { UserRole } from '../../common/enums/user-role.enum';
import { UsersService } from '../../users/services/users.service';
import { UpdateDriverProfileDto } from '../dto/update-driver-profile.dto';
import { DriverProfileEntity } from '../entities/driver-profile.entity';
import { DriverProfilesRepository } from '../repositories/driver-profiles.repository';
import { DriverProfileValidatorService } from './driver-profile-validator.service';

@Injectable()
export class DriversService {
  constructor(
    private readonly usersService: UsersService,
    private readonly profilesRepository: DriverProfilesRepository,
    private readonly validator: DriverProfileValidatorService
  ) {}

  ensureProfile(userId: string): DriverProfileEntity {
    this.assertDriverRole(userId);

    const existing = this.profilesRepository.findByUserId(userId);
    if (existing) {
      return existing;
    }

    return this.profilesRepository.create(userId);
  }

  getProfileOrThrow(userId: string): DriverProfileEntity {
    const profile = this.profilesRepository.findByUserId(userId);
    if (!profile) {
      throw new NotFoundException('Driver profile not found.');
    }

    return profile;
  }

  updateProfile(userId: string, input: UpdateDriverProfileDto): DriverProfileEntity {
    this.assertDriverRole(userId);

    const current = this.ensureProfile(userId);
    const updated: DriverProfileEntity = {
      ...current,
      ...input,
      updatedAt: new Date()
    };

    return this.profilesRepository.save(updated);
  }

  updateStatus(userId: string, status: DriverStatus): DriverProfileEntity {
    this.assertDriverRole(userId);

    const current = this.ensureProfile(userId);

    if (status === DriverStatus.ONLINE) {
      this.validator.assertCanGoOnline(current);
    }

    const updated: DriverProfileEntity = {
      ...current,
      status,
      updatedAt: new Date()
    };

    return this.profilesRepository.save(updated);
  }

  listOnlineDriverIds(): string[] {
    return this.profilesRepository
      .listAll()
      .filter((profile) => profile.status === DriverStatus.ONLINE)
      .map((profile) => profile.userId);
  }

  toPublicProfile(profile: DriverProfileEntity): {
    userId: string;
    status: DriverStatus;
    documentId?: string;
    documentExpiry?: string;
    neighborhood?: string;
    operatingRegion?: string;
    isProfileComplete: boolean;
    updatedAt: Date;
  } {
    return {
      userId: profile.userId,
      status: profile.status,
      documentId: profile.documentId,
      documentExpiry: profile.documentExpiry,
      neighborhood: profile.neighborhood,
      operatingRegion: profile.operatingRegion,
      isProfileComplete: this.validator.isProfileComplete(profile),
      updatedAt: profile.updatedAt
    };
  }

  private assertDriverRole(userId: string): void {
    const user = this.usersService.findByIdOrThrow(userId);

    if (user.role !== UserRole.DRIVER) {
      throw new ForbiddenException('Only drivers can access this endpoint.');
    }
  }
}
