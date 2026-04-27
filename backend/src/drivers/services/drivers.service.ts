import {
  ForbiddenException,
  Injectable,
  Logger,
  OnModuleInit,
  NotFoundException
} from '@nestjs/common';
import { DriverStatus } from '../../common/enums/driver-status.enum';
import { UserRole } from '../../common/enums/user-role.enum';
import { isAuthorizationBypassEnabled } from '../../common/utils/auth-bypass.util';
import { RealtimeEventsService } from '../../realtime/events/realtime-events.service';
import { SubscriptionsService } from '../../subscriptions/services/subscriptions.service';
import { UsersService } from '../../users/services/users.service';
import { UpdateDriverProfileDto } from '../dto/update-driver-profile.dto';
import { DriverProfileEntity } from '../entities/driver-profile.entity';
import { DriverProfilesRepository } from '../repositories/driver-profiles.repository';
import { DriverPresenceStore } from '../store/driver-presence.store';
import { DriverProfileValidatorService } from './driver-profile-validator.service';

@Injectable()
export class DriversService implements OnModuleInit {
  private readonly logger = new Logger(DriversService.name);

  constructor(
    private readonly usersService: UsersService,
    private readonly profilesRepository: DriverProfilesRepository,
    private readonly presenceStore: DriverPresenceStore,
    private readonly validator: DriverProfileValidatorService,
    private readonly subscriptionsService: SubscriptionsService,
    private readonly realtimeEvents: RealtimeEventsService
  ) {}

  async onModuleInit(): Promise<void> {
    const profiles = await this.profilesRepository.listAll();
    const onlineDriverIds = profiles
      .filter((profile) => profile.status === DriverStatus.ONLINE)
      .map((profile) => profile.userId);

    await this.presenceStore.replaceOnlineDriverIds(onlineDriverIds);
    this.logger.log(
      `Driver presence synchronized (${onlineDriverIds.length} online).`
    );
  }

  async ensureProfile(userId: string): Promise<DriverProfileEntity> {
    await this.assertDriverRole(userId);

    const existing = await this.profilesRepository.findByUserId(userId);
    if (existing) {
      return existing;
    }

    return this.profilesRepository.create(userId);
  }

  async getProfileOrThrow(userId: string): Promise<DriverProfileEntity> {
    const profile = await this.profilesRepository.findByUserId(userId);
    if (!profile) {
      throw new NotFoundException('Driver profile not found.');
    }

    return profile;
  }

  async updateProfile(
    userId: string,
    input: UpdateDriverProfileDto
  ): Promise<DriverProfileEntity> {
    const current = await this.ensureProfile(userId);
    const updated: DriverProfileEntity = {
      ...current,
      ...input,
      updatedAt: new Date()
    };

    return this.profilesRepository.save(updated);
  }

  async updateStatus(
    userId: string,
    status: DriverStatus
  ): Promise<DriverProfileEntity> {
    const current = await this.ensureProfile(userId);

    if (status === DriverStatus.ONLINE) {
      this.validator.assertCanGoOnline(current);
      await this.subscriptionsService.assertDriverCanOperate(userId);
    }

    const updated: DriverProfileEntity = {
      ...current,
      status,
      updatedAt: new Date()
    };

    const saved = await this.profilesRepository.save(updated);
    await this.syncPresence(saved.userId, saved.status);
    this.realtimeEvents.emitDriverStatusUpdated({
      driverId: saved.userId,
      status: saved.status,
      updatedAt: saved.updatedAt.toISOString()
    });

    return saved;
  }

  async listOnlineDriverIds(): Promise<string[]> {
    return this.presenceStore.listOnlineDriverIds();
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

  private async assertDriverRole(userId: string): Promise<void> {
    if (isAuthorizationBypassEnabled()) {
      return;
    }

    const user = await this.usersService.findByIdOrThrow(userId);

    if (user.role !== UserRole.DRIVER) {
      throw new ForbiddenException('Only drivers can access this endpoint.');
    }
  }

  private async syncPresence(
    userId: string,
    status: DriverStatus
  ): Promise<void> {
    if (status === DriverStatus.ONLINE) {
      await this.presenceStore.setOnline(userId);
      return;
    }

    await this.presenceStore.setOffline(userId);
  }
}
