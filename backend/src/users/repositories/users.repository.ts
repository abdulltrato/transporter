import { randomUUID } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { UserRole } from '../../common/enums/user-role.enum';
import { UserEntity } from '../entities/user.entity';

export interface CreateUserInput {
  fullName: string;
  phone: string;
  role: UserRole;
}

@Injectable()
export class UsersRepository {
  private readonly usersById = new Map<string, UserEntity>();
  private readonly userIdByPhone = new Map<string, string>();

  create(input: CreateUserInput): UserEntity {
    const now = new Date();
    const user: UserEntity = {
      id: randomUUID(),
      fullName: input.fullName,
      phone: input.phone,
      role: input.role,
      createdAt: now,
      updatedAt: now
    };

    this.usersById.set(user.id, user);
    this.userIdByPhone.set(user.phone, user.id);

    return user;
  }

  findByPhone(phone: string): UserEntity | undefined {
    const userId = this.userIdByPhone.get(phone);
    return userId ? this.usersById.get(userId) : undefined;
  }

  findById(userId: string): UserEntity | undefined {
    return this.usersById.get(userId);
  }

  updateFullName(userId: string, fullName: string): UserEntity | undefined {
    const current = this.usersById.get(userId);
    if (!current) {
      return undefined;
    }

    const updated: UserEntity = {
      ...current,
      fullName,
      updatedAt: new Date()
    };

    this.usersById.set(userId, updated);
    return updated;
  }
}
