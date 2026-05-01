import { Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  OnGatewayInit,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { getJwtSecret } from '../../auth/config/jwt.config';
import { JwtPayload } from '../../auth/interfaces/jwt-payload.interface';
import { UserRole } from '../../common/enums/user-role.enum';
import { RequestUser } from '../../common/interfaces/request-user.interface';
import {
  getBypassUserProfile,
  isAuthBypassEnabled,
  resolveBypassRole
} from '../../common/utils/auth-bypass.util';
import { DriversService } from '../../drivers/services/drivers.service';
import { LocationService } from '../../location/services/location.service';
import { UsersService } from '../../users/services/users.service';
import {
  MAP_SUBSCRIBERS_ROOM,
  REALTIME_NAMESPACE,
  getUserRealtimeRoom
} from '../constants/realtime.constants';
import { RealtimeEventsService } from '../events/realtime-events.service';

interface MapSubscriptionPayload {
  lat?: number;
  lng?: number;
  radiusKm?: number;
}

@WebSocketGateway({
  namespace: REALTIME_NAMESPACE,
  cors: {
    origin: true,
    credentials: true
  }
})
export class RealtimeGateway
  implements OnGatewayInit, OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer()
  private server!: Server;

  private readonly logger = new Logger(RealtimeGateway.name);
  private readonly connectedUsers = new Map<string, RequestUser>();

  constructor(
    private readonly jwtService: JwtService,
    private readonly realtimeEvents: RealtimeEventsService,
    private readonly driversService: DriversService,
    private readonly locationService: LocationService,
    private readonly usersService: UsersService
  ) {}

  afterInit(server: Server): void {
    this.realtimeEvents.registerServer(server);
    this.logger.log('Realtime gateway ready.');
  }

  async handleConnection(client: Socket): Promise<void> {
    const user = await this.authenticateClient(client);
    if (!user) {
      return;
    }

    this.connectedUsers.set(client.id, user);
    client.join(getUserRealtimeRoom(user.id));
  }

  handleDisconnect(client: Socket): void {
    this.connectedUsers.delete(client.id);
  }

  @SubscribeMessage('map:subscribe')
  async onMapSubscribe(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: MapSubscriptionPayload = {}
  ): Promise<void> {
    if (!this.connectedUsers.has(client.id)) {
      this.disconnectUnauthorized(client, 'Authentication required.');
      return;
    }

    client.join(MAP_SUBSCRIBERS_ROOM);

    const lat = payload.lat;
    const lng = payload.lng;
    if (!this.isFiniteNumber(lat) || !this.isFiniteNumber(lng)) {
      return;
    }

    const radiusKm = this.isFiniteNumber(payload.radiusKm)
      ? Math.max(0.5, payload.radiusKm)
      : 5;
    const candidateDriverIds = await this.driversService.listOnlineDriverIds();
    const nearbyDrivers = await this.locationService.findNearbyDrivers({
      origin: { lat, lng },
      radiusKm,
      candidateDriverIds
    });

    client.emit('map:snapshot', {
      origin: { lat, lng },
      radiusKm,
      generatedAt: new Date().toISOString(),
      drivers: nearbyDrivers.map((driver) => ({
        driverId: driver.driverId,
        coordinates: driver.coordinates,
        distanceKm: driver.distanceKm,
        updatedAt: driver.updatedAt.toISOString()
      }))
    });
  }

  @SubscribeMessage('map:unsubscribe')
  onMapUnsubscribe(@ConnectedSocket() client: Socket): void {
    client.leave(MAP_SUBSCRIBERS_ROOM);
  }

  private async authenticateClient(client: Socket): Promise<RequestUser | undefined> {
    const headerSessionUser = await this.resolveHeaderSessionUser(client);
    if (headerSessionUser) {
      return headerSessionUser;
    }

    if (isAuthBypassEnabled()) {
      return this.resolveBypassUser(client);
    }

    const token = this.extractToken(client);

    if (!token) {
      this.disconnectUnauthorized(client, 'Missing token.');
      return undefined;
    }

    try {
      const payload = this.jwtService.verify<JwtPayload>(token, {
        secret: getJwtSecret()
      });

      if (!Object.values(UserRole).includes(payload.role)) {
        throw new Error('Invalid role.');
      }

      return {
        id: payload.sub,
        phone: payload.phone,
        role: payload.role
      };
    } catch {
      this.disconnectUnauthorized(client, 'Invalid or expired token.');
      return undefined;
    }
  }

  private async resolveHeaderSessionUser(
    client: Socket
  ): Promise<RequestUser | undefined> {
    const headerUserId = this.toFirstString(
      client.handshake.headers['x-transporter-user-id']
    );
    const authUserId = this.toFirstString(client.handshake.auth?.['userId']);
    const queryUserId = this.toFirstString(client.handshake.query['userId']);
    const userId = headerUserId ?? authUserId ?? queryUserId;

    if (!userId) {
      return undefined;
    }

    const user = await this.usersService.findById(userId);
    if (!user) {
      this.disconnectUnauthorized(client, 'Invalid x-transporter-user-id.');
      return undefined;
    }

    return {
      id: user.id,
      phone: user.phone,
      role: user.role
    };
  }

  private async resolveBypassUser(client: Socket): Promise<RequestUser | undefined> {
    const roleHeader = this.toFirstString(client.handshake.headers['x-transporter-role']);
    const role = resolveBypassRole({
      headerRole: roleHeader,
      token: this.extractToken(client)
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
      this.disconnectUnauthorized(client, 'Bypass user initialization failed.');
      return undefined;
    }

    return {
      id: user.id,
      phone: user.phone,
      role: user.role
    };
  }

  private extractToken(client: Socket): string | undefined {
    const authToken = client.handshake.auth?.token;
    if (typeof authToken === 'string' && authToken.trim().length > 0) {
      return authToken.trim();
    }

    const authorizationHeader = client.handshake.headers.authorization;
    if (typeof authorizationHeader === 'string') {
      const [scheme, token] = authorizationHeader.split(' ');
      if (scheme.toLowerCase() === 'bearer' && token) {
        return token.trim();
      }
    }

    const queryToken = client.handshake.query.token;
    if (typeof queryToken === 'string' && queryToken.trim().length > 0) {
      return queryToken.trim();
    }

    return undefined;
  }

  private isFiniteNumber(value: unknown): value is number {
    return typeof value === 'number' && Number.isFinite(value);
  }

  private toFirstString(value: unknown): string | undefined {
    if (Array.isArray(value) && value.length > 0) {
      const first = value[0];
      return typeof first === 'string' ? first : undefined;
    }

    if (typeof value === 'string') {
      return value;
    }

    return undefined;
  }

  private disconnectUnauthorized(client: Socket, reason: string): void {
    client.emit('auth:error', { message: reason });
    client.disconnect(true);
  }
}
