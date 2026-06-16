import { readLocalEvents, trackLocalEvent } from "@/lib/local-analytics";
import type {
  ArchiveAttachmentLevelId,
  ArchiveAttachmentReasonId,
  ArchiveMoatPerceptionId,
} from "@/types/archive-attachment";

export const ARCHIVE_ATTACHMENT_EVENT_NAMES = {
  level: "archive_attachment_level" as const,
  reason: "archive_attachment_reason" as const,
  moatPerception: "archive_moat_perception" as const,
};

export function trackArchiveAttachmentLevel(meta: {
  level: ArchiveAttachmentLevelId;
  score: number;
  attributionId: string;
  reflectionCount: number;
  archiveAgeDays: number;
}): void {
  trackLocalEvent(ARCHIVE_ATTACHMENT_EVENT_NAMES.level, {
    level: meta.level,
    score: String(meta.score),
    attributionId: meta.attributionId,
    reflectionCount: String(meta.reflectionCount),
    archiveAgeDays: String(meta.archiveAgeDays),
  });
}

export function trackArchiveAttachmentReason(meta: {
  reason: ArchiveAttachmentReasonId;
  attributionId: string;
  level: ArchiveAttachmentLevelId;
}): void {
  trackLocalEvent(ARCHIVE_ATTACHMENT_EVENT_NAMES.reason, {
    reason: meta.reason,
    attributionId: meta.attributionId,
    level: meta.level,
  });
}

export function trackArchiveAttachmentMoatPerception(meta: {
  perception: ArchiveMoatPerceptionId;
  attributionId: string;
  level: ArchiveAttachmentLevelId;
}): void {
  trackLocalEvent(ARCHIVE_ATTACHMENT_EVENT_NAMES.moatPerception, {
    archive_moat_perception: meta.perception,
    attributionId: meta.attributionId,
    level: meta.level,
  });
}

export function clearArchiveAttachmentEventsForEval(): void {
  if (typeof window === "undefined") return;
  try {
    const raw = localStorage.getItem("voicememory_local_events");
    if (!raw) return;
    const names = new Set<string>(Object.values(ARCHIVE_ATTACHMENT_EVENT_NAMES));
    const events = JSON.parse(raw) as Array<{ name: string }>;
    const filtered = events.filter((e) => !names.has(e.name));
    localStorage.setItem("voicememory_local_events", JSON.stringify(filtered));
  } catch {
    /* ignore */
  }
}
