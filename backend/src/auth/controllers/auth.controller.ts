import { Body, Controller, Post } from '@nestjs/common';
import { Public } from '../../common/decorators/public.decorator';
import { RegisterUserDto } from '../dto/register-user.dto';
import { RequestOtpDto } from '../dto/request-otp.dto';
import { SocialAuthDto } from '../dto/social-auth.dto';
import { VerifyOtpDto } from '../dto/verify-otp.dto';
import { AuthService } from '../services/auth.service';

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Public()
  @Post('register')
  register(
    @Body() body: RegisterUserDto
  ): ReturnType<AuthService['register']> {
    return this.authService.register(body);
  }

  @Public()
  @Post('request-otp')
  requestOtp(@Body() body: RequestOtpDto): Promise<{
    requestId: string;
    expiresAt: Date;
    devCode?: string;
  }> {
    return this.authService.requestOtp(body);
  }

  @Public()
  @Post('verify-otp')
  verifyOtp(
    @Body() body: VerifyOtpDto
  ): ReturnType<AuthService['verifyOtp']> {
    return this.authService.verifyOtp(body);
  }

  @Public()
  @Post('social')
  socialAuth(
    @Body() body: SocialAuthDto
  ): ReturnType<AuthService['socialLogin']> {
    return this.authService.socialLogin(body);
  }
}
