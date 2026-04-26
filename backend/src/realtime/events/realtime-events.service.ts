import { Injectable } from '@nestjs/common';
import { Server } from 'socket.io';
import { DriverStatus } from '../../common/enums/driver-status.enum';
import { GeoPoint } from '../../common/interfaces/geo-point.interface';
import { RideEntity } from '../../rides/entities/ride.entity';
import { MAP_SUBSCRIBERS_ROOM, getUserRealtimeRoom } from '../constants/realtime.constants';

export interface DriverStatusEventPayload {
  driverId: string;
  status: DriverStatus;
  updatedAt: string;
}

export interface DriverLocationEventPayload {
  driverId: string;
  coordinates: GeoPoint;
  updatedAt: string;
}

@Injectable()
export class RealtimeEventsService {
  private server?: Server;

  registerServer(server: Server): void {
    this.server = server;
  }

  emitDriverStatusUpdated(payload: DriverStatusEventPayload): void {
    if (!this.server) {
      return;
    }

    this.server.to(MAP_SUBSCRIBERS_ROOM).emit('driver:status', payload);
  }

  emitDriverLocationUpdated(payload: DriverLocationEventPayload): void {
    if (!this.server) {
      return;
    }

    this.server.to(MAP_SUBSCRIBERS_ROOM).emit('driver:location', payload);
  }

  emitRideUpdated(ride: RideEntity): void {
    if (!this.server) {
      return;
    }

    const payload = {
      ...ride,
      createdAt: ride.createdAt.toISOString(),
      updatedAt: ride.updatedAt.toISOString()
    };

    this.server
      .to(getUserRealtimeRoom(ride.clientId))
      .emit('ride:updated', payload);

    if (ride.driverId) {
      this.server
        .to(getUserRealtimeRoom(ride.driverId))
        .emit('ride:updated', payload);
    }
  }
}
