import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Reflector } from '@nestjs/core';
import { PUBLIC_ROUTE_KEY } from '../decorators/public.decorator';
import { RequestUser } from '../interfaces/request-user.interface';
import { getJwtSecret } from '../../auth/config/jwt.config';

interface JwtPayload {
  sub: string;
  phone: string;
  role: string;
}

@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly jwtService: JwtService
  ) {}

  canActivate(context: ExecutionContext): boolean {
    if (context.getType() !== 'http') {
      return true;
    }

    const isPublicRoute = this.reflector.getAllAndOverride<boolean>(PUBLIC_ROUTE_KEY, [
      context.getHandler(),
      context.getClass()
    ]);

    if (isPublicRoute) {
      return true;
    }

    const request = context.switchToHttp().getRequest<{
      headers: Record<string, string | string[] | undefined>;
      user?: RequestUser;
    }>();

    const rawHeader = request.headers.authorization;
    const headerValue = Array.isArray(rawHeader) ? rawHeader[0] : rawHeader;

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
}
