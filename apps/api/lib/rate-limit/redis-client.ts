import Redis from "ioredis";

let redisClient: Redis | null = null;

export function isRedisRateLimitConfigured(): boolean {
  return Boolean(process.env.REDIS_URL?.trim());
}

export function getRedisClient(): Redis | null {
  const url = process.env.REDIS_URL?.trim();
  if (!url) return null;

  if (!redisClient) {
    redisClient = new Redis(url, {
      maxRetriesPerRequest: 1,
      enableOfflineQueue: false,
      lazyConnect: true,
    });
  }

  return redisClient;
}

export async function closeRedisClient(): Promise<void> {
  if (!redisClient) return;
  const client = redisClient;
  redisClient = null;
  await client.quit();
}

export function resetRedisClientForTest(): void {
  redisClient = null;
}
