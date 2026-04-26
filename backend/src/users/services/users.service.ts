import { Injectable, NotFoundException } from '@nestjs/common';
import { CreateUserInput, UsersRepository } from '../repositories/users.repository';
import { UserEntity } from '../entities/user.entity';

@Injectable()
export class UsersService {
  constructor(private readonly usersRepository: UsersRepository) {}

  async create(input: CreateUserInput): Promise<UserEntity> {
    return this.usersRepository.create(input);
  }

  async findByPhone(phone: string): Promise<UserEntity | undefined> {
    return this.usersRepository.findByPhone(phone);
  }

  async findByIdOrThrow(userId: string): Promise<UserEntity> {
    const user = await this.usersRepository.findById(userId);

    if (!user) {
      throw new NotFoundException('User not found.');
    }

    return user;
  }

  async updateMyProfile(userId: string, fullName: string): Promise<UserEntity> {
    const updated = await this.usersRepository.updateFullName(userId, fullName);

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
