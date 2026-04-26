import {
  Injectable,
  Logger,
  OnApplicationShutdown,
  OnModuleInit
} from '@nestjs/common';
import Redis from 'ioredis';

@Injectable()
export class RedisService implements OnModuleInit, OnApplicationShutdown {
  private readonly logger = new Logger(RedisService.name);

  private readonly client: Redis = this.createClient();

  async onModuleInit(): Promise<void> {
    await this.client.ping();
    this.logger.log('Redis connection initialized.');
  }

  async onApplicationShutdown(): Promise<void> {
    await this.client.quit();
  }

  getClient(): Redis {
    return this.client;
  }

  private createClient(): Redis {
    if (process.env.REDIS_URL) {
      return new Redis(process.env.REDIS_URL);
    }

    return new Redis({
      host: process.env.REDIS_HOST ?? 'localhost',
      port: Number(process.env.REDIS_PORT ?? 6379),
      password: process.env.REDIS_PASSWORD,
      db: Number(process.env.REDIS_DB ?? 0)
    });
  }
}
