import { SocialProvider } from '../enums/social-provider.enum';

export interface SocialIdentityEntity {
  userId: string;
  provider: SocialProvider;
  providerUserId: string;
  createdAt: Date;
  updatedAt: Date;
}
