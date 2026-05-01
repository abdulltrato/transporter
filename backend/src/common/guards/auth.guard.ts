import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Reflector } from '@nestjs/core';
import { UsersService } from '../../users/services/users.service';
import { PUBLIC_ROUTE_KEY } from '../decorators/public.decorator';
import { RequestUser } from '../interfaces/request-user.interface';
import { getJwtSecret } from '../../auth/config/jwt.config';
import {
  getBypassUserProfile,
  isAuthBypassEnabled,
  resolveBypassRole
} from '../utils/auth-bypass.util';

interface JwtPayload {
  sub: string;
  phone: string;
  role: string;
}

@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly jwtService: JwtService,
    private readonly usersService: UsersService
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    if (context.getType() !== 'http') {
      return true;
    }

    const request = context.switchToHttp().getRequest<{
      headers: Record<string, string | string[] | undefined>;
      user?: RequestUser;
    }>();

    const isPublicRoute = this.reflector.getAllAndOverride<boolean>(PUBLIC_ROUTE_KEY, [
      context.getHandler(),
      context.getClass()
    ]);

    const sessionUser = await this.resolveHeaderSessionUser(request.headers);
    if (sessionUser) {
      request.user = sessionUser;
      return true;
    }

    if (isPublicRoute) {
      return true;
    }

    if (isAuthBypassEnabled()) {
      request.user = await this.resolveBypassUser(request.headers);
      return true;
    }

    const headerValue = this.getHeaderValue(request.headers, 'authorization');

    if (!headerValue) {
      throw new UnauthorizedException('Missing authorization header.');
    }

    const [scheme, token] = headerValue.split(' ');
    if (scheme !== 'Bearer' || !token) {
      throw new UnauthorizedException('Authorization header must be Bearer <token>.');
    }

    try {
      const payload = this.jwtService.verify<JwtPayload>(token, {
        secret: getJwtSecret()
      });

      request.user = {
        id: payload.sub,
        phone: payload.phone,
        role: payload.role as RequestUser['role']
      };

      return true;
    } catch {
      throw new UnauthorizedException('Invalid or expired token.');
    }
  }

  private async resolveHeaderSessionUser(
    headers: Record<string, string | string[] | undefined>
  ): Promise<RequestUser | undefined> {
    const userId = this.getHeaderValue(headers, 'x-transporter-user-id');
    if (!userId) {
      return undefined;
    }

    const user = await this.usersService.findById(userId);
    if (!user) {
      return undefined;
    }

    return {
      id: user.id,
      phone: user.phone,
      role: user.role
    };
  }

  private async resolveBypassUser(
    headers: Record<string, string | string[] | undefined>
  ): Promise<RequestUser> {
    const roleHeader = this.getHeaderValue(headers, 'x-transporter-role');
    const authorizationHeader = this.getHeaderValue(headers, 'authorization');
    const token = this.extractBearerToken(authorizationHeader);
    const role = resolveBypassRole({
      headerRole: roleHeader,
      token
    });
    const profile = getBypassUserProfile(role);

    let user = await this.usersService.findByPhone(profile.phone);
    if (!user) {
      try {
        user = await this.usersService.create({
          fullName: profile.fullName,
          phone: profile.phone,
          role
        });
      } catch {
        user = await this.usersService.findByPhone(profile.phone);
      }
    }

    if (!user) {
      throw new UnauthorizedException('Failed to initialize bypass test user.');
    }

    return {
      id: user.id,
      phone: user.phone,
      role: user.role
    };
  }

  private getHeaderValue(
    headers: Record<string, string | string[] | undefined>,
    key: string
  ): string | undefined {
    const rawValue = headers[key];
    const headerValue = Array.isArray(rawValue) ? rawValue[0] : rawValue;

    if (!headerValue || headerValue.trim().length === 0) {
      return undefined;
    }

    return headerValue.trim();
  }

  private extractBearerToken(authorizationHeader?: string): string | undefined {
    if (!authorizationHeader) {
      return undefined;
    }

    const [scheme, token] = authorizationHeader.split(' ');
    if (scheme.toLowerCase() !== 'bearer' || !token) {
      return undefined;
    }

    return token.trim();
  }
}
