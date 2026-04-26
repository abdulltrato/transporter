import { randomUUID } from 'node:crypto';
import { Injectable } from '@nestjs/common';
import { UserRole } from '../../common/enums/user-role.enum';
import { DatabaseService } from '../../database/services/database.service';
import { UserEntity } from '../entities/user.entity';

export interface CreateUserInput {
  fullName: string;
  phone: string;
  role: UserRole;
}

@Injectable()
export class UsersRepository {
  constructor(private readonly database: DatabaseService) {}

  async create(input: CreateUserInput): Promise<UserEntity> {
    const now = new Date();
    const result = await this.database.query<UserRow>(
      `
        INSERT INTO users (id, full_name, phone, role, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING id, full_name, phone, role, created_at, updated_at
      `,
      [randomUUID(), input.fullName, input.phone, input.role, now, now]
    );

    const created = result.rows[0];
    return this.toEntity(created);
  }

  async findByPhone(phone: string): Promise<UserEntity | undefined> {
    const result = await this.database.query<UserRow>(
      `
        SELECT id, full_name, phone, role, created_at, updated_at
        FROM users
        WHERE phone = $1
        LIMIT 1
      `,
      [phone]
    );

    const row = result.rows[0];
    return row ? this.toEntity(row) : undefined;
  }

  async findById(userId: string): Promise<UserEntity | undefined> {
    const result = await this.database.query<UserRow>(
      `
        SELECT id, full_name, phone, role, created_at, updated_at
        FROM users
        WHERE id = $1
        LIMIT 1
      `,
      [userId]
    );

    const row = result.rows[0];
    return row ? this.toEntity(row) : undefined;
  }

  async updateFullName(
    userId: string,
    fullName: string
  ): Promise<UserEntity | undefined> {
    const result = await this.database.query<UserRow>(
      `
        UPDATE users
        SET full_name = $2, updated_at = $3
        WHERE id = $1
        RETURNING id, full_name, phone, role, created_at, updated_at
      `,
      [userId, fullName, new Date()]
    );

    const row = result.rows[0];
    if (!row) {
      return undefined;
    }

    return this.toEntity(row);
  }

  private toEntity(row: UserRow): UserEntity {
    return {
      id: row.id,
      fullName: row.full_name,
      phone: row.phone,
      role: row.role,
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at)
    };
  }
}

interface UserRow {
  id: string;
  full_name: string;
  phone: string;
  role: UserRole;
  created_at: Date | string;
  updated_at: Date | string;
}
