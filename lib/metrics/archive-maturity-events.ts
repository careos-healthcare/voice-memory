import { readLocalEvents, trackLocalEvent } from "@/lib/local-analytics";

export const ARCHIVE_MATURITY_EVENT_NAMES = {
  seen: "archive_maturity_seen" as const,
  clicked: "archive_maturity_clicked" as const,
};

export function trackArchiveMaturitySeen(meta?: { stage?: string; surface?: string }): void {
  trackLocalEvent(ARCHIVE_MATURITY_EVENT_NAMES.seen, {
    stage: meta?.stage ?? "",
    surface: meta?.surface ?? "",
  });
}

export function trackArchiveMaturityClicked(meta?: { stage?: string; surface?: string }): void {
  trackLocalEvent(ARCHIVE_MATURITY_EVENT_NAMES.clicked, {
    stage: meta?.stage ?? "",
    surface: meta?.surface ?? "",
  });
}

export function countArchiveMaturityEvent(
  name: (typeof ARCHIVE_MATURITY_EVENT_NAMES)[keyof typeof ARCHIVE_MATURITY_EVENT_NAMES],
): number {
  return readLocalEvents().filter((e) => e.name === name).length;
}
