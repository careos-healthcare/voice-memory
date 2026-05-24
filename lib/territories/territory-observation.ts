import { trackLocalEvent } from "@/lib/local-analytics";

export const TERRITORY_OPENED = "territory_opened";
export const TERRITORY_RENAMED = "territory_renamed";
export const TERRITORY_ENTRY_REVISITED = "territory_entry_revisited";
export const TERRITORY_CONTINUE_CLICKED = "territory_continue_clicked";

export function trackTerritoryOpened(territoryId: string, slug: string): void {
  trackLocalEvent(TERRITORY_OPENED, { territoryId, slug });
}

export function trackTerritoryRenamed(territoryId: string, label: string): void {
  trackLocalEvent(TERRITORY_RENAMED, { territoryId, label: label.slice(0, 80) });
}

export function trackTerritoryEntryRevisited(
  territoryId: string,
  entryId: string,
): void {
  trackLocalEvent(TERRITORY_ENTRY_REVISITED, { territoryId, entryId });
}

export function trackTerritoryContinueClicked(
  territoryId: string,
  target: "roundups" | "intentions" | "feelings",
): void {
  trackLocalEvent(TERRITORY_CONTINUE_CLICKED, { territoryId, target });
}
