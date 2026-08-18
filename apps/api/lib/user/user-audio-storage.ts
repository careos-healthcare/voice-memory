import "server-only";

export interface UserAudioStorageDeleteResult {
  ok: boolean;
  deletedCount: number;
  prefix: string;
}

/** Deletes encrypted audio objects under `users/{userId}/audio/`. */
export interface UserAudioStorageProvider {
  deleteUserAudioPrefix(userId: string): Promise<UserAudioStorageDeleteResult>;
}

const audioPrefix = (userId: string) => `users/${userId}/audio/`;

/**
 * Default object-storage adapter — no-op until S3/GCS credentials are wired.
 * Replace via dependency injection in tests or production bootstrap.
 */
export class NoOpUserAudioStorageProvider implements UserAudioStorageProvider {
  async deleteUserAudioPrefix(userId: string): Promise<UserAudioStorageDeleteResult> {
    return {
      ok: true,
      deletedCount: 0,
      prefix: audioPrefix(userId),
    };
  }
}

let defaultProvider: UserAudioStorageProvider = new NoOpUserAudioStorageProvider();

export function getUserAudioStorageProvider(): UserAudioStorageProvider {
  return defaultProvider;
}

/** Test/production override for S3, GCS, or Vercel Blob adapters. */
export function setUserAudioStorageProvider(provider: UserAudioStorageProvider): void {
  defaultProvider = provider;
}

export function resetUserAudioStorageProviderForTest(): void {
  defaultProvider = new NoOpUserAudioStorageProvider();
}

export { audioPrefix as userAudioStoragePrefix };
