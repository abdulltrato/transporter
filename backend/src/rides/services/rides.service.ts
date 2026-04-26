import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException
} from '@nestjs/common';
import { RideStatus } from '../../common/enums/ride-status.enum';
import { UserRole } from '../../common/enums/user-role.enum';
import { RequestUser } from '../../common/interfaces/request-user.interface';
import { RidesRepository } from '../repositories/rides.repository';
import { RideEntity } from '../entities/ride.entity';
import { RideResponseAction } from '../dto/respond-ride.dto';
import { DriverMatchingService } from './driver-matching.service';

@Injectable()
export class RidesService {
  constructor(
    private readonly ridesRepository: RidesRepository,
    private readonly matchingService: DriverMatchingService
  ) {}

  async requestRide(
    currentUser: RequestUser,
    pickup: RideEntity['pickup'],
    dropoff?: RideEntity['dropoff']
  ): Promise<RideEntity> {
    if (currentUser.role !== UserRole.CLIENT) {
      throw new ForbiddenException('Only clients can request rides.');
    }

    const match = await this.matchingService.findClosestDriver({ pickup });

    if (!match) {
      return this.ridesRepository.create({
        clientId: currentUser.id,
        pickup,
        dropoff,
        status: RideStatus.SEARCHING,
        rejectedDriverIds: []
      });
    }

    return this.ridesRepository.create({
      clientId: currentUser.id,
      pickup,
      dropoff,
      status: RideStatus.ASSIGNED,
      driverId: match.driverId,
      searchRadiusKm: match.radiusKm,
      rejectedDriverIds: []
    });
  }

  async respondToRide(
    currentUser: RequestUser,
    rideId: string,
    action: RideResponseAction
  ): Promise<RideEntity> {
    if (currentUser.role !== UserRole.DRIVER) {
      throw new ForbiddenException('Only drivers can answer rides.');
    }

    const ride = await this.findByIdOrThrow(rideId);

    if (ride.driverId !== currentUser.id) {
      throw new ForbiddenException('This ride is not assigned to this driver.');
    }

    if (![RideStatus.ASSIGNED, RideStatus.SEARCHING].includes(ride.status)) {
      throw new BadRequestException('Ride is no longer available for response.');
    }

    if (action === RideResponseAction.ACCEPT) {
      return this.ridesRepository.save({
        ...ride,
        status: RideStatus.ACCEPTED
      });
    }

    const rejectedDriverIds = [...new Set([...ride.rejectedDriverIds, currentUser.id])];
    const nextMatch = await this.matchingService.findClosestDriver({
      pickup: ride.pickup,
      excludedDriverIds: rejectedDriverIds
    });

    if (!nextMatch) {
      return this.ridesRepository.save({
        ...ride,
        status: RideStatus.SEARCHING,
        driverId: undefined,
        searchRadiusKm: undefined,
        rejectedDriverIds
      });
    }

    return this.ridesRepository.save({
      ...ride,
      status: RideStatus.ASSIGNED,
      driverId: nextMatch.driverId,
      searchRadiusKm: nextMatch.radiusKm,
      rejectedDriverIds
    });
  }

  async cancelRide(currentUser: RequestUser, rideId: string): Promise<RideEntity> {
    const ride = await this.findByIdOrThrow(rideId);

    if (currentUser.role !== UserRole.CLIENT || ride.clientId !== currentUser.id) {
      throw new ForbiddenException('Only the client who requested the ride can cancel it.');
    }

    if ([RideStatus.CANCELLED, RideStatus.COMPLETED].includes(ride.status)) {
      throw new BadRequestException('Ride is already closed.');
    }

    return this.ridesRepository.save({
      ...ride,
      status: RideStatus.CANCELLED
    });
  }

  async listMyRides(currentUser: RequestUser): Promise<RideEntity[]> {
    if (currentUser.role === UserRole.CLIENT) {
      return this.ridesRepository.listByClientId(currentUser.id);
    }

    return this.ridesRepository.listByDriverId(currentUser.id);
  }

  private async findByIdOrThrow(rideId: string): Promise<RideEntity> {
    const ride = await this.ridesRepository.findById(rideId);

    if (!ride) {
      throw new NotFoundException('Ride not found.');
    }

    return ride;
  }
}
