import { BadRequestException, Injectable } from '@nestjs/common';
import { UserRole } from '../../common/enums/user-role.enum';
import { DriversService } from '../../drivers/services/drivers.service';
import { UsersService } from '../../users/services/users.service';
import { RequestOtpDto } from '../dto/request-otp.dto';
import { VerifyOtpDto } from '../dto/verify-otp.dto';
import { OtpService } from './otp.service';
import { TokenService } from './token.service';

@Injectable()
export class AuthService {
  constructor(
    private readonly otpService: OtpService,
    private readonly usersService: UsersService,
    private readonly driversService: DriversService,
    private readonly tokenService: TokenService
  ) {}

  requestOtp(input: RequestOtpDto): { requestId: string; expiresAt: Date; devCode: string } {
    return this.otpService.issue(input.phone);
  }

  async verifyOtp(input: VerifyOtpDto): Promise<{
    accessToken: string;
    tokenType: 'Bearer';
    user: ReturnType<UsersService['toPublicUser']>;
  }> {
    this.otpService.validate(input.phone, input.code);

    let user = await this.usersService.findByPhone(input.phone);

    if (!user) {
      if (!input.fullName) {
        throw new BadRequestException('fullName is required for first login.');
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
}
