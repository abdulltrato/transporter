import { Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { UserEntity } from '../../users/entities/user.entity';
import { JwtPayload } from '../interfaces/jwt-payload.interface';

@Injectable()
export class TokenService {
  constructor(private readonly jwtService: JwtService) {}

  async signAccessToken(user: UserEntity): Promise<string> {
    const payload: JwtPayload = {
      sub: user.id,
      phone: user.phone,
      role: user.role
    };

    return this.jwtService.signAsync(payload);
  }
}
