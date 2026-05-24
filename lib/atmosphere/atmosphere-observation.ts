import { trackLocalEvent } from "@/lib/local-analytics";
import type { AtmosphereStyle } from "@/types/atmosphere";

export const ATMOSPHERE_CREATED = "atmosphere_created";
export const ATMOSPHERE_DELETED = "atmosphere_deleted";
export const ATMOSPHERE_REVISITED = "atmosphere_revisited";

export function trackAtmosphereCreated(entryId: string, style: AtmosphereStyle, source: string): void {
  trackLocalEvent(ATMOSPHERE_CREATED, { entryId, style, source });
}

export function trackAtmosphereDeleted(entryId: string): void {
  trackLocalEvent(ATMOSPHERE_DELETED, { entryId });
}

export function trackAtmosphereRevisited(entryId: string): void {
  trackLocalEvent(ATMOSPHERE_REVISITED, { entryId });
}
