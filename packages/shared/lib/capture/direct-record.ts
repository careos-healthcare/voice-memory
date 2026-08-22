import { QUICK_ENTRY_PATH } from "@/lib/mobile/quick-entry";

export type DirectRecordSource =
  | "resurfacing"
  | "open_loop"
  | "clarity"
  | "return"
  | "reflex"
  | "home";

export interface DirectRecordParams {
  source?: DirectRecordSource;
  quote?: string;
  loopId?: string;
  entryId?: string;
  autostart?: boolean;
}

/** Build `/record` href with preserved context — homepage not required. */
export function buildDirectRecordHref(params: DirectRecordParams = {}): string {
  const search = new URLSearchParams();
  if (params.source) search.set("source", params.source);
  if (params.quote?.trim()) search.set("quote", params.quote.trim().slice(0, 220));
  if (params.loopId) search.set("loopId", params.loopId);
  if (params.entryId) search.set("entryId", params.entryId);
  if (params.autostart === false) search.set("autostart", "0");
  const qs = search.toString();
  return qs ? `${QUICK_ENTRY_PATH}?${qs}` : QUICK_ENTRY_PATH;
}

export function openDirectToRecordingHref(params: DirectRecordParams = {}): string {
  return buildDirectRecordHref({ autostart: true, ...params });
}
