/**
 * Per-store deletion contract shared by every backend store touched during
 * account deletion (`lib/server/account-deletion.ts`). Every store — across
 * all three runtime storage modes (Postgres / filesystem / memory) — reports
 * one of these, so a partial failure is always visible and never silently
 * misreported as full success.
 */
export type StoreDeletionMode = "postgres" | "filesystem" | "memory" | "not_applicable";

export interface StoreDeletionResult {
  /** Logical store name, e.g. "journal", "sync_blobs", "sessions", "billing", "push_devices". */
  store: string;
  mode: StoreDeletionMode;
  ok: boolean;
  /** Rows/files/entries removed — counts only, never row content. */
  count?: number;
  /** Present only when ok === false. Must never contain transcripts, emails, or raw tokens/ids. */
  error?: string;
}

export interface AccountDeletionResult {
  /** True only if every REQUIRED_DELETION_STORES entry succeeded. Best-effort stores can fail without flipping this. */
  ok: boolean;
  stores: StoreDeletionResult[];
}

/**
 * Stores whose failure means the deletion as a whole must be reported as
 * incomplete (ok: false) — these are the stores that could otherwise leave a
 * user's account effectively "not deleted" (their content, ability to sync,
 * billing state, or push targeting would still be live). Every other store
 * in the contract is still executed and honestly reported, but a failure
 * there is treated as best-effort (e.g. analytics/rate-limit rows) and does
 * not by itself flip the overall result to failed.
 */
export const REQUIRED_DELETION_STORES: readonly string[] = [
  "journal",
  "sync_blobs",
  "sessions",
  "billing",
  "push_devices",
];

function truncateForAudit(message: string): string {
  return message.length > 200 ? `${message.slice(0, 200)}…` : message;
}

export function safeDeletionErrorMessage(error: unknown): string {
  const message = error instanceof Error ? error.message : String(error);
  return truncateForAudit(message);
}

export async function runStoreDeletion(
  store: string,
  mode: StoreDeletionMode,
  fn: () => Promise<number> | number,
): Promise<StoreDeletionResult> {
  try {
    const count = await fn();
    return { store, mode, ok: true, count };
  } catch (error) {
    return { store, mode, ok: false, error: safeDeletionErrorMessage(error) };
  }
}

/**
 * For a store that genuinely does not exist/apply in the current mode (e.g.
 * there is no server-side session table outside Postgres, or a store is not
 * user-keyed at all). Always `ok: true` — there is nothing to fail — but
 * `count` is only set when a count of zero is a meaningful, honest statement
 * ("checked, nothing there"); leave it undefined when there is no concept of
 * a count at all (e.g. a store that isn't user-keyed), so a reader never
 * mistakes "not applicable" for "zero rows deleted".
 */
export function notApplicableStoreResult(store: string, count?: number): StoreDeletionResult {
  return { store, mode: "not_applicable", ok: true, ...(count !== undefined ? { count } : {}) };
}

export function computeOverallOk(stores: StoreDeletionResult[]): boolean {
  return stores
    .filter((s) => REQUIRED_DELETION_STORES.includes(s.store))
    .every((s) => s.ok);
}
