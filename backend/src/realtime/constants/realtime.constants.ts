export const REALTIME_NAMESPACE = '/realtime';
export const MAP_SUBSCRIBERS_ROOM = 'map:subscribers';

export function getUserRealtimeRoom(userId: string): string {
  return `user:${userId}`;
}
