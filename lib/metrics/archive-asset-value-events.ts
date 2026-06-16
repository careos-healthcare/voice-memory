import { readLocalEvents, trackLocalEvent } from "@/lib/local-analytics";

export const ARCHIVE_ASSET_EVENT_NAMES = {
  seen: "archive_asset_card_seen" as const,
  exportClicked: "archive_asset_export_clicked" as const,
};

export function trackArchiveAssetCardSeen(meta?: { surface?: string }): void {
  trackLocalEvent(ARCHIVE_ASSET_EVENT_NAMES.seen, { surface: meta?.surface ?? "" });
}

export function trackArchiveAssetExportClicked(meta?: { surface?: string }): void {
  trackLocalEvent(ARCHIVE_ASSET_EVENT_NAMES.exportClicked, { surface: meta?.surface ?? "" });
}

export function countArchiveAssetEvent(
  name: (typeof ARCHIVE_ASSET_EVENT_NAMES)[keyof typeof ARCHIVE_ASSET_EVENT_NAMES],
): number {
  return readLocalEvents().filter((e) => e.name === name).length;
}
