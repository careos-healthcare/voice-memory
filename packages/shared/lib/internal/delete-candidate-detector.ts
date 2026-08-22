import type { InternalArchiveRecord } from "@/types/internal-archive";

const STALE_DAYS = 30;

/**
 * Mark dashboards DELETE_CANDIDATE when they have no events, no usage, no decisions,
 * and have been stale 30+ days (proxy via staleSinceDays on archived routes).
 */
export function applyDeleteCandidateRules(
  records: InternalArchiveRecord[],
): InternalArchiveRecord[] {
  return records.map((record) => {
    if (record.status === "ACTIVE") return record;

    const noSignals =
      !record.hasEvents && !record.hasUsageSignals && !record.drivesDecisions;
    const staleLong =
      (record.staleSinceDays ?? (record.status === "ARCHIVED" ? STALE_DAYS : 0)) >= STALE_DAYS;

    if (noSignals && staleLong) {
      return {
        ...record,
        status: "DELETE_CANDIDATE",
        staleReason:
          record.staleReason ??
          "No events, usage, or decisions for 30+ days — candidate for route removal",
      };
    }

    return record;
  });
}

export function listDeleteCandidates(
  records: InternalArchiveRecord[] = [],
): InternalArchiveRecord[] {
  const rows = records.length > 0 ? records : [];
  return rows.filter((r) => r.status === "DELETE_CANDIDATE");
}
