import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DriversModule } from '../drivers/drivers.module';
import { UsersModule } from '../users/users.module';
import { getJwtExpiresIn, getJwtSecret } from './config/jwt.config';
import { AuthController } from './controllers/auth.controller';
import { AuthService } from './services/auth.service';
import { OtpService } from './services/otp.service';
import { TokenService } from './services/token.service';
import { OtpStore } from './store/otp.store';

@Module({
  imports: [
    JwtModule.register({
      secret: getJwtSecret(),
      signOptions: {
        expiresIn: getJwtExpiresIn()
      }
    }),
    UsersModule,
    DriversModule
  ],
  controllers: [AuthController],
  providers: [OtpStore, OtpService, TokenService, AuthService],
  exports: [JwtModule, TokenService]
})
export class AuthModule {}
