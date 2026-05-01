import { BadRequestException, Injectable } from '@nestjs/common';
import { createHash } from 'node:crypto';
import { UserRole } from '../../common/enums/user-role.enum';
import { DriversService } from '../../drivers/services/drivers.service';
import { UsersService } from '../../users/services/users.service';
import { RegisterUserDto } from '../dto/register-user.dto';
import { RequestOtpDto } from '../dto/request-otp.dto';
import { SocialAuthDto } from '../dto/social-auth.dto';
import { VerifyOtpDto } from '../dto/verify-otp.dto';
import { SocialIdentitiesRepository } from '../repositories/social-identities.repository';
import { OtpService } from './otp.service';
import { TokenService } from './token.service';

@Injectable()
export class AuthService {
  constructor(
    private readonly otpService: OtpService,
    private readonly usersService: UsersService,
    private readonly driversService: DriversService,
    private readonly socialIdentitiesRepository: SocialIdentitiesRepository,
    private readonly tokenService: TokenService
  ) {}

  async register(input: RegisterUserDto): Promise<{
    user: ReturnType<UsersService['toPublicUser']>;
    session: {
      userId: string;
      role: UserRole;
    };
  }> {
    const phone = input.phone.trim();
    const fullName = input.fullName.trim();

    let user = await this.usersService.findByPhone(phone);
    if (!user) {
      user = await this.usersService.create({
        fullName,
        phone,
        role: input.role
      });
    } else if (user.role !== input.role) {
      throw new BadRequestException(
        'This phone number is already linked to a different role.'
      );
    } else if (fullName && fullName !== user.fullName) {
      user = await this.usersService.updateMyProfile(user.id, fullName);
    }

    if (user.role === UserRole.DRIVER) {
      await this.driversService.ensureProfile(user.id);
      const profileUpdate = this.buildDriverProfileUpdate(input);

      if (Object.keys(profileUpdate).length > 0) {
        await this.driversService.updateProfile(user.id, profileUpdate);
      }
    }

    return {
      user: this.usersService.toPublicUser(user),
      session: {
        userId: user.id,
        role: user.role
      }
    };
  }

  async requestOtp(input: RequestOtpDto): Promise<{
    requestId: string;
    expiresAt: Date;
    devCode?: string;
  }> {
    return this.otpService.issue(input.phone);
  }

  async verifyOtp(input: VerifyOtpDto): Promise<{
    accessToken: string;
    tokenType: 'Bearer';
    user: ReturnType<UsersService['toPublicUser']>;
  }> {
    await this.otpService.validate(input.phone, input.code);

    let user = await this.usersService.findByPhone(input.phone);
    const isFirstLogin = !user;

    if (!user) {
      if (!input.fullName) {
        throw new BadRequestException('fullName is required for first login.');
      }

      if (input.role === UserRole.DRIVER) {
        this.assertDriverRegistrationData(input);
      }

      user = await this.usersService.create({
        fullName: input.fullName,
        phone: input.phone,
        role: input.role
      });
    }

    if (user.role !== input.role) {
      throw new BadRequestException('This phone number is already linked to a different role.');
    }

    if (input.role === UserRole.DRIVER) {
      await this.driversService.ensureProfile(user.id);

      if (
        isFirstLogin ||
        input.documentId ||
        input.documentExpiry ||
        input.neighborhood ||
        input.operatingRegion
      ) {
        await this.driversService.updateProfile(user.id, {
          documentId: input.documentId,
          documentExpiry: input.documentExpiry,
          neighborhood: input.neighborhood,
          operatingRegion: input.operatingRegion
        });
      }
    }

    const accessToken = await this.tokenService.signAccessToken(user);

    return {
      accessToken,
      tokenType: 'Bearer',
      user: this.usersService.toPublicUser(user)
    };
  }

  async socialLogin(input: SocialAuthDto): Promise<{
    accessToken: string;
    tokenType: 'Bearer';
    user: ReturnType<UsersService['toPublicUser']>;
  }> {
    const providerUserId = input.providerUserId.trim();
    if (!providerUserId) {
      throw new BadRequestException('providerUserId is required.');
    }

    const linkedIdentity =
      await this.socialIdentitiesRepository.findByProviderUserId(
        input.provider,
        providerUserId
      );

    let user = linkedIdentity
      ? await this.usersService.findByIdOrThrow(linkedIdentity.userId)
      : undefined;

    if (!user) {
      const fullName = input.fullName?.trim();
      if (!fullName) {
        throw new BadRequestException('fullName is required for first social login.');
      }

      if (input.role === UserRole.DRIVER) {
        this.assertDriverRegistrationData(input);
      }

      const syntheticPhone = this.buildSyntheticPhone(
        input.provider,
        providerUserId
      );
      user = await this.usersService.create({
        fullName,
        phone: syntheticPhone,
        role: input.role
      });

      await this.socialIdentitiesRepository.create({
        userId: user.id,
        provider: input.provider,
        providerUserId
      });
    }

    if (user.role !== input.role) {
      throw new BadRequestException(
        'This social account is already linked to a different role.'
      );
    }

    if (input.role === UserRole.DRIVER) {
      await this.driversService.ensureProfile(user.id);

      if (
        input.documentId ||
        input.documentExpiry ||
        input.neighborhood ||
        input.operatingRegion
      ) {
        await this.driversService.updateProfile(user.id, {
          documentId: input.documentId,
          documentExpiry: input.documentExpiry,
          neighborhood: input.neighborhood,
          operatingRegion: input.operatingRegion
        });
      }
    }

    const accessToken = await this.tokenService.signAccessToken(user);
    return {
      accessToken,
      tokenType: 'Bearer',
      user: this.usersService.toPublicUser(user)
    };
  }

  private buildSyntheticPhone(
    provider: SocialAuthDto['provider'],
    providerUserId: string
  ): string {
    const hash = createHash('sha256')
      .update(`${provider}:${providerUserId}`)
      .digest('hex');
    const digits = hash
      .split('')
      .map((char) => char.charCodeAt(0) % 10)
      .join('')
      .slice(0, 12);
    return `+999${digits}`;
  }

  private assertDriverRegistrationData(input: {
    documentId?: string;
    documentExpiry?: string;
    neighborhood?: string;
    operatingRegion?: string;
  }): void {
    if (!input.documentId?.trim()) {
      throw new BadRequestException(
        'documentId is required for driver registration.'
      );
    }

    if (!input.documentExpiry?.trim()) {
      throw new BadRequestException(
        'documentExpiry is required for driver registration.'
      );
    }

    if (!input.neighborhood?.trim()) {
      throw new BadRequestException(
        'neighborhood is required for driver registration.'
      );
    }

    if (!input.operatingRegion?.trim()) {
      throw new BadRequestException(
        'operatingRegion is required for driver registration.'
      );
    }
  }

  private buildDriverProfileUpdate(
    input: Pick<
      RegisterUserDto,
      'documentId' | 'documentExpiry' | 'neighborhood' | 'operatingRegion'
    >
  ): {
    documentId?: string;
    documentExpiry?: string;
    neighborhood?: string;
    operatingRegion?: string;
  } {
    const update: {
      documentId?: string;
      documentExpiry?: string;
      neighborhood?: string;
      operatingRegion?: string;
    } = {};

    const documentId = input.documentId?.trim();
    if (documentId) {
      update.documentId = documentId;
    }

    const documentExpiry = input.documentExpiry?.trim();
    if (documentExpiry) {
      update.documentExpiry = documentExpiry;
    }

    const neighborhood = input.neighborhood?.trim();
    if (neighborhood) {
      update.neighborhood = neighborhood;
    }

    const operatingRegion = input.operatingRegion?.trim();
    if (operatingRegion) {
      update.operatingRegion = operatingRegion;
    }

    return update;
  }
}
