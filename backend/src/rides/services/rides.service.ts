import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException
} from '@nestjs/common';
import { RideStatus } from '../../common/enums/ride-status.enum';
import { UserRole } from '../../common/enums/user-role.enum';
import { RequestUser } from '../../common/interfaces/request-user.interface';
import { RealtimeEventsService } from '../../realtime/events/realtime-events.service';
import { RidesRepository } from '../repositories/rides.repository';
import { RideEntity } from '../entities/ride.entity';
import { RideResponseAction } from '../dto/respond-ride.dto';
import { DriverMatchingService } from './driver-matching.service';

@Injectable()
export class RidesService {
  constructor(
    private readonly ridesRepository: RidesRepository,
    private readonly matchingService: DriverMatchingService,
    private readonly realtimeEvents: RealtimeEventsService
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

    let ride: RideEntity;

    if (!match) {
      ride = await this.ridesRepository.create({
        clientId: currentUser.id,
        pickup,
        dropoff,
        status: RideStatus.SEARCHING,
        rejectedDriverIds: []
      });
    } else {
      ride = await this.ridesRepository.create({
        clientId: currentUser.id,
        pickup,
        dropoff,
        status: RideStatus.ASSIGNED,
        driverId: match.driverId,
        searchRadiusKm: match.radiusKm,
        rejectedDriverIds: []
      });
    }

    this.realtimeEvents.emitRideUpdated(ride);
    return ride;
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
      const acceptedRide = await this.ridesRepository.save({
        ...ride,
        status: RideStatus.ACCEPTED
      });

      this.realtimeEvents.emitRideUpdated(acceptedRide);
      return acceptedRide;
    }

    const rejectedDriverIds = [...new Set([...ride.rejectedDriverIds, currentUser.id])];
    const nextMatch = await this.matchingService.findClosestDriver({
      pickup: ride.pickup,
      excludedDriverIds: rejectedDriverIds
    });

    if (!nextMatch) {
      const updatedRide = await this.ridesRepository.save({
        ...ride,
        status: RideStatus.SEARCHING,
        driverId: undefined,
        searchRadiusKm: undefined,
        rejectedDriverIds
      });

      this.realtimeEvents.emitRideUpdated(updatedRide);
      return updatedRide;
    }

    const reassignedRide = await this.ridesRepository.save({
      ...ride,
      status: RideStatus.ASSIGNED,
      driverId: nextMatch.driverId,
      searchRadiusKm: nextMatch.radiusKm,
      rejectedDriverIds
    });

    this.realtimeEvents.emitRideUpdated(reassignedRide);
    return reassignedRide;
  }

  async cancelRide(currentUser: RequestUser, rideId: string): Promise<RideEntity> {
    const ride = await this.findByIdOrThrow(rideId);

    if (currentUser.role !== UserRole.CLIENT || ride.clientId !== currentUser.id) {
      throw new ForbiddenException('Only the client who requested the ride can cancel it.');
    }

    if ([RideStatus.CANCELLED, RideStatus.COMPLETED].includes(ride.status)) {
      throw new BadRequestException('Ride is already closed.');
    }

    const cancelledRide = await this.ridesRepository.save({
      ...ride,
      status: RideStatus.CANCELLED
    });

    this.realtimeEvents.emitRideUpdated(cancelledRide);
    return cancelledRide;
  }

  async startRide(currentUser: RequestUser, rideId: string): Promise<RideEntity> {
    if (currentUser.role !== UserRole.DRIVER) {
      throw new ForbiddenException('Only drivers can start rides.');
    }

    const ride = await this.findByIdOrThrow(rideId);

    if (ride.driverId !== currentUser.id) {
      throw new ForbiddenException('This ride is not assigned to this driver.');
    }

    if (ride.status !== RideStatus.ACCEPTED) {
      throw new BadRequestException('Ride must be accepted before start.');
    }

    const startedRide = await this.ridesRepository.save({
      ...ride,
      status: RideStatus.IN_PROGRESS
    });

    this.realtimeEvents.emitRideUpdated(startedRide);
    return startedRide;
  }

  async completeRide(currentUser: RequestUser, rideId: string): Promise<RideEntity> {
    if (currentUser.role !== UserRole.DRIVER) {
      throw new ForbiddenException('Only drivers can complete rides.');
    }

    const ride = await this.findByIdOrThrow(rideId);

    if (ride.driverId !== currentUser.id) {
      throw new ForbiddenException('This ride is not assigned to this driver.');
    }

    if (ride.status !== RideStatus.IN_PROGRESS) {
      throw new BadRequestException('Ride must be in progress before completion.');
    }

    const completedRide = await this.ridesRepository.save({
      ...ride,
      status: RideStatus.COMPLETED
    });

    this.realtimeEvents.emitRideUpdated(completedRide);
    return completedRide;
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
