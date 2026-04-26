import { Body, Controller, Get, Patch } from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { RequestUser } from '../../common/interfaces/request-user.interface';
import { UpdateMyProfileDto } from '../dto/update-my-profile.dto';
import { UsersService } from '../services/users.service';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  getMe(@CurrentUser() currentUser: RequestUser): ReturnType<UsersService['toPublicUser']> {
    const user = this.usersService.findByIdOrThrow(currentUser.id);
    return this.usersService.toPublicUser(user);
  }

  @Patch('me')
  updateMe(
    @CurrentUser() currentUser: RequestUser,
    @Body() body: UpdateMyProfileDto
  ): ReturnType<UsersService['toPublicUser']> {
    const updated = this.usersService.updateMyProfile(currentUser.id, body.fullName);
    return this.usersService.toPublicUser(updated);
  }
}
