import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException
} from '@nestjs/common';
import { UserRole } from '../../common/enums/user-role.enum';
import { RequestUser } from '../../common/interfaces/request-user.interface';
import { RideStatus } from '../../common/enums/ride-status.enum';
import { isAuthorizationBypassEnabled } from '../../common/utils/auth-bypass.util';
import { RidesRepository } from '../../rides/repositories/rides.repository';
import { SubmitDriverRatingDto } from '../dto/submit-driver-rating.dto';
import { DriverRatingEntity } from '../entities/driver-rating.entity';
import { DriverRatingsRepository } from '../repositories/driver-ratings.repository';

@Injectable()
export class RatingsService {
  constructor(
    private readonly ridesRepository: RidesRepository,
    private readonly ratingsRepository: DriverRatingsRepository
  ) {}

  async submitDriverRating(
    currentUser: RequestUser,
    input: SubmitDriverRatingDto
  ): Promise<DriverRatingEntity> {
    const authzBypassEnabled = isAuthorizationBypassEnabled();

    if (!authzBypassEnabled && currentUser.role !== UserRole.CLIENT) {
      throw new ForbiddenException('Only clients can rate drivers.');
    }

    const ride = await this.ridesRepository.findById(input.rideId);
    if (!ride) {
      throw new NotFoundException('Ride not found.');
    }

    if (!authzBypassEnabled && ride.clientId !== currentUser.id) {
      throw new ForbiddenException('You can only rate rides requested by you.');
    }

    if (!ride.driverId) {
      throw new BadRequestException('Ride has no driver to rate.');
    }

    if (ride.status !== RideStatus.COMPLETED) {
      throw new BadRequestException('Driver can only be rated after ride completion.');
    }

    return this.ratingsRepository.upsert({
      rideId: ride.id,
      driverId: ride.driverId,
      clientId: currentUser.id,
      stars: input.stars
    });
  }

  async listMyGivenRatings(currentUser: RequestUser): Promise<DriverRatingEntity[]> {
    if (!isAuthorizationBypassEnabled() && currentUser.role !== UserRole.CLIENT) {
      throw new ForbiddenException('Only clients can list given ratings.');
    }

    return this.ratingsRepository.listByClientId(currentUser.id);
  }

  async getDriverSummary(driverId: string): Promise<{
    driverId: string;
    totalRatings: number;
    averageStars: number;
    star1: number;
    star2: number;
    star3: number;
    star4: number;
    star5: number;
  }> {
    const summary = await this.ratingsRepository.getDriverSummary(driverId);
    return {
      driverId,
      ...summary
    };
  }

  toPublicRating(rating: DriverRatingEntity): {
    id: string;
    rideId: string;
    driverId: string;
    clientId: string;
    stars: number;
    satisfactionLabel: string;
    createdAt: Date;
    updatedAt: Date;
  } {
    return {
      id: rating.id,
      rideId: rating.rideId,
      driverId: rating.driverId,
      clientId: rating.clientId,
      stars: rating.stars,
      satisfactionLabel: this.getSatisfactionLabel(rating.stars),
      createdAt: rating.createdAt,
      updatedAt: rating.updatedAt
    };
  }

  private getSatisfactionLabel(stars: number): string {
    return (
      {
        1: 'Insatisfeito',
        2: 'Pouco satisfeito',
        3: 'Satisfeito',
        4: 'Muito satisfeito',
        5: 'Super satisfeito'
      }[stars] ?? 'Sem classificação'
    );
  }
}
