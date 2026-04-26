import { randomUUID } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { RideStatus } from '../../common/enums/ride-status.enum';
import { GeoPoint } from '../../common/interfaces/geo-point.interface';
import { RideEntity } from '../entities/ride.entity';

export interface CreateRideInput {
  clientId: string;
  pickup: GeoPoint;
  dropoff?: GeoPoint;
  status: RideStatus;
  driverId?: string;
  searchRadiusKm?: number;
  rejectedDriverIds?: string[];
}

@Injectable()
export class RidesRepository {
  private readonly ridesById = new Map<string, RideEntity>();

  create(input: CreateRideInput): RideEntity {
    const now = new Date();
    const ride: RideEntity = {
      id: randomUUID(),
      clientId: input.clientId,
      pickup: input.pickup,
      dropoff: input.dropoff,
      status: input.status,
      driverId: input.driverId,
      searchRadiusKm: input.searchRadiusKm,
      rejectedDriverIds: input.rejectedDriverIds ?? [],
      createdAt: now,
      updatedAt: now
    };

    this.ridesById.set(ride.id, ride);
    return ride;
  }

  findById(rideId: string): RideEntity | undefined {
    return this.ridesById.get(rideId);
  }

  save(ride: RideEntity): RideEntity {
    this.ridesById.set(ride.id, {
      ...ride,
      updatedAt: new Date()
    });

    return this.ridesById.get(ride.id) as RideEntity;
  }

  listByClientId(clientId: string): RideEntity[] {
    return this.listAll().filter((ride) => ride.clientId === clientId);
  }

  listByDriverId(driverId: string): RideEntity[] {
    return this.listAll().filter((ride) => ride.driverId === driverId);
  }

  private listAll(): RideEntity[] {
    return Array.from(this.ridesById.values()).sort(
      (a, b) => b.createdAt.getTime() - a.createdAt.getTime()
    );
  }
}
