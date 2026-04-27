import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { RequestUser } from '../../common/interfaces/request-user.interface';
import { SubmitDriverRatingDto } from '../dto/submit-driver-rating.dto';
import { RatingsService } from '../services/ratings.service';

@Controller('ratings')
export class RatingsController {
  constructor(private readonly ratingsService: RatingsService) {}

  @Post('driver')
  async submitDriverRating(
    @CurrentUser() currentUser: RequestUser,
    @Body() body: SubmitDriverRatingDto
  ): Promise<ReturnType<RatingsService['toPublicRating']>> {
    const rating = await this.ratingsService.submitDriverRating(currentUser, body);
    return this.ratingsService.toPublicRating(rating);
  }

  @Get('me/given')
  async listMyGivenRatings(
    @CurrentUser() currentUser: RequestUser
  ): Promise<ReturnType<RatingsService['toPublicRating']>[]> {
    const ratings = await this.ratingsService.listMyGivenRatings(currentUser);
    return ratings.map((item) => this.ratingsService.toPublicRating(item));
  }

  @Public()
  @Get('drivers/:driverId/summary')
  getDriverSummary(@Param('driverId') driverId: string): ReturnType<
    RatingsService['getDriverSummary']
  > {
    return this.ratingsService.getDriverSummary(driverId);
  }
}
