import { Injectable, NotFoundException } from '@nestjs/common';
import { CreateUserInput, UsersRepository } from '../repositories/users.repository';
import { UserEntity } from '../entities/user.entity';

@Injectable()
export class UsersService {
  constructor(private readonly usersRepository: UsersRepository) {}

  create(input: CreateUserInput): UserEntity {
    return this.usersRepository.create(input);
  }

  findByPhone(phone: string): UserEntity | undefined {
    return this.usersRepository.findByPhone(phone);
  }

  findByIdOrThrow(userId: string): UserEntity {
    const user = this.usersRepository.findById(userId);

    if (!user) {
      throw new NotFoundException('User not found.');
    }

    return user;
  }

  updateMyProfile(userId: string, fullName: string): UserEntity {
    const updated = this.usersRepository.updateFullName(userId, fullName);

    if (!updated) {
      throw new NotFoundException('User not found.');
    }

    return updated;
  }

  toPublicUser(user: UserEntity): {
    id: string;
    fullName: string;
    phone: string;
    role: UserEntity['role'];
    createdAt: Date;
  } {
    return {
      id: user.id,
      fullName: user.fullName,
      phone: user.phone,
      role: user.role,
      createdAt: user.createdAt
    };
  }
}
