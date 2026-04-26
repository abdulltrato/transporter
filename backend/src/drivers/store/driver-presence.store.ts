import { Injectable } from '@nestjs/common';
import { RedisService } from '../../redis/services/redis.service';

@Injectable()
export class DriverPresenceStore {
  private readonly onlineDriversKey = 'transporter:presence:online_drivers';

  constructor(private readonly redisService: RedisService) {}

  async setOnline(driverId: string): Promise<void> {
    await this.redisService.getClient().sadd(this.onlineDriversKey, driverId);
  }

  async setOffline(driverId: string): Promise<void> {
    await this.redisService.getClient().srem(this.onlineDriversKey, driverId);
  }

  async listOnlineDriverIds(): Promise<string[]> {
    return this.redisService.getClient().smembers(this.onlineDriversKey);
  }

  async replaceOnlineDriverIds(driverIds: string[]): Promise<void> {
    const client = this.redisService.getClient();
    const pipeline = client.pipeline();

    pipeline.del(this.onlineDriversKey);
    if (driverIds.length > 0) {
      pipeline.sadd(this.onlineDriversKey, ...driverIds);
    }

    await pipeline.exec();
  }
}
