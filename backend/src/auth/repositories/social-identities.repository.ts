import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../../database/services/database.service';
import { SocialIdentityEntity } from '../entities/social-identity.entity';
import { SocialProvider } from '../enums/social-provider.enum';

export interface CreateSocialIdentityInput {
  userId: string;
  provider: SocialProvider;
  providerUserId: string;
}

@Injectable()
export class SocialIdentitiesRepository {
  constructor(private readonly database: DatabaseService) {}

  async findByProviderUserId(
    provider: SocialProvider,
    providerUserId: string
  ): Promise<SocialIdentityEntity | undefined> {
    const result = await this.database.query<SocialIdentityRow>(
      `
        SELECT user_id, provider, provider_user_id, created_at, updated_at
        FROM user_social_identities
        WHERE provider = $1 AND provider_user_id = $2
        LIMIT 1
      `,
      [provider, providerUserId]
    );

    const row = result.rows[0];
    return row ? this.toEntity(row) : undefined;
  }

  async create(input: CreateSocialIdentityInput): Promise<SocialIdentityEntity> {
    const now = new Date();
    const result = await this.database.query<SocialIdentityRow>(
      `
        INSERT INTO user_social_identities (
          user_id,
          provider,
          provider_user_id,
          created_at,
          updated_at
        )
        VALUES ($1, $2, $3, $4, $5)
        RETURNING user_id, provider, provider_user_id, created_at, updated_at
      `,
      [input.userId, input.provider, input.providerUserId, now, now]
    );

    return this.toEntity(result.rows[0]);
  }

  private toEntity(row: SocialIdentityRow): SocialIdentityEntity {
    return {
      userId: row.user_id,
      provider: row.provider,
      providerUserId: row.provider_user_id,
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at)
    };
  }
}

interface SocialIdentityRow {
  user_id: string;
  provider: SocialProvider;
  provider_user_id: string;
  created_at: Date | string;
  updated_at: Date | string;
}
