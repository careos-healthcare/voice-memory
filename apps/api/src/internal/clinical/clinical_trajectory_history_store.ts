import "server-only";

/**
 * INTERNAL CLINICAL QUARANTINE — not for public API surfaces.
 * @module src/internal/clinical/clinical_trajectory_history_store
 */

export interface StoredTrajectoryRecord {
  date: string;
  directionValue: string;
  lexicalDelta: number;
  driftDelta: number;
  wasGrounded: boolean;
  entryId?: string;
  hookId?: string;
  volatilityDelta?: number;
}

export class ClinicalTrajectoryHistoryStore {
  private readonly records = new Map<string, StoredTrajectoryRecord[]>();

  async append(userId: string, record: StoredTrajectoryRecord): Promise<void> {
    const key = userId.trim();
    if (!key) throw new Error("userId is required for trajectory history.");
    const existing = this.records.get(key) ?? [];
    existing.push(record);
    this.records.set(key, existing);
  }

  async list(userId: string): Promise<readonly StoredTrajectoryRecord[]> {
    const key = userId.trim();
    if (!key) return [];
    return [...(this.records.get(key) ?? [])];
  }

  async clear(userId: string): Promise<void> {
    this.records.delete(userId.trim());
  }
}

/** Process-local singleton — never expose via HTTP handlers. */
export const clinicalTrajectoryHistoryStore = new ClinicalTrajectoryHistoryStore();

export function storedTrajectoryRecordFromJson(json: unknown): StoredTrajectoryRecord | null {
  if (typeof json !== "object" || json === null) return null;
  const map = json as Record<string, unknown>;
  const dateRaw = map.date ?? map.recordedAt;
  const directionValue = map.direction;
  const lexicalDelta = parseScore(map.lexicalDelta);
  const driftDelta = parseScore(map.driftDelta);
  if (
    typeof dateRaw !== "string" ||
    !Number.isFinite(Date.parse(dateRaw)) ||
    typeof directionValue !== "string" ||
    lexicalDelta == null ||
    driftDelta == null
  ) {
    return null;
  }

  const volatilityDelta = parseScore(map.volatilityDelta);
  return {
    date: new Date(dateRaw).toISOString(),
    directionValue,
    lexicalDelta,
    driftDelta,
    wasGrounded: map.wasGrounded === true,
    entryId: typeof map.entryId === "string" ? map.entryId : undefined,
    hookId: typeof map.hookId === "string" ? map.hookId : undefined,
    volatilityDelta: volatilityDelta ?? undefined,
  };
}

function parseScore(raw: unknown): number | null {
  if (typeof raw !== "number" || !Number.isFinite(raw)) return null;
  return raw;
}
