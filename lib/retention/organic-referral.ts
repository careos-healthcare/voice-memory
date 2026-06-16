import { readAllBlindSpotFeedback } from "@/lib/blind-spots/blind-spot-feedback";
import { readAllTheoryFeedback } from "@/lib/theories/theory-feedback";
import { THEORY_EVENTS, readAllTheoryEvents } from "@/lib/theories/theory-events";
import { ACTIVATION_METRIC_EVENTS } from "@/lib/product/activation-metrics";
import {
  trackOrganicReferralReason,
  trackOrganicReferralStatus,
  trackReferralBlocker,
} from "@/lib/metrics/organic-referral-events";
import {
  ORGANIC_REFERRAL_REASON_LABELS,
  REFERRAL_BLOCKER_LABELS,
} from "@/lib/retention/organic-referral-copy";
import { buildArchiveValueSnapshot } from "@/lib/product/archive-value-progress";
import { readLocalEvents } from "@/lib/local-analytics";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type {
  OrganicReferralReasonId,
  OrganicReferralRecord,
  OrganicReferralStatusId,
  ReferralBlockerId,
} from "@/types/organic-referral";
import type { JournalEntry } from "@/types/journal";

export const ORGANIC_REFERRAL_LAST_SHOWN_KEY = "voicememory_organic_referral_last_shown";
export const ORGANIC_REFERRAL_RECORDS_KEY = "voicememory_organic_referral_records";
export const ORGANIC_REFERRAL_PENDING_FOLLOWUP_KEY =
  "voicememory_organic_referral_pending_followup";

export const ORGANIC_REFERRAL_MIN_REFLECTIONS = 5;
export const ORGANIC_REFERRAL_COOLDOWN_MS = 14 * 24 * 60 * 60 * 1000;

const MAX_RECORDS = 120;

const STRONG_BLIND_SPOT = new Set(["surprising", "uncomfortably_accurate"]);
const STRONG_THEORY = new Set(["surprising"]);

function getStorage(): Storage | null {
  if (typeof window === "undefined") return null;
  return localStorage;
}

function newId(prefix: string): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return `${prefix}-${crypto.randomUUID()}`;
  }
  return `${prefix}-${Date.now()}`;
}

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

function hasStrongReaction(): boolean {
  const blind = readAllBlindSpotFeedback().some((f) => STRONG_BLIND_SPOT.has(f.reaction));
  if (blind) return true;
  const theory = readAllTheoryFeedback().some((f) => STRONG_THEORY.has(f.reaction));
  if (theory) return true;
  return readLocalEvents().some(
    (e) => e.name === ACTIVATION_METRIC_EVENTS.strongInsightReaction,
  );
}

function hasDiscoverVisit(): boolean {
  if (readAllTheoryEvents().some((e) => e.name === THEORY_EVENTS.discoverOpened)) {
    return true;
  }
  return readLocalEvents().some((e) => e.name === "discover_opened");
}

export function meetsOrganicReferralEligibility(entriesInput?: JournalEntry[]): boolean {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  const { reflectionCount } = buildArchiveValueSnapshot(entries);
  if (reflectionCount < ORGANIC_REFERRAL_MIN_REFLECTIONS) return false;
  if (!hasStrongReaction()) return false;
  if (!hasDiscoverVisit()) return false;
  return true;
}

function readRecords(): OrganicReferralRecord[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(ORGANIC_REFERRAL_RECORDS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as OrganicReferralRecord[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeRecords(rows: OrganicReferralRecord[]): void {
  getStorage()?.setItem(
    ORGANIC_REFERRAL_RECORDS_KEY,
    JSON.stringify(rows.slice(-MAX_RECORDS)),
  );
}

export function canShowOrganicReferralPrompt(
  now = Date.now(),
  entriesInput?: JournalEntry[],
): boolean {
  const store = getStorage();
  if (!store) return false;
  if (!meetsOrganicReferralEligibility(entriesInput)) return false;

  const last = store.getItem(ORGANIC_REFERRAL_LAST_SHOWN_KEY);
  if (!last) return true;
  return now - new Date(last).getTime() >= ORGANIC_REFERRAL_COOLDOWN_MS;
}

export function markOrganicReferralPromptShown(): void {
  getStorage()?.setItem(ORGANIC_REFERRAL_LAST_SHOWN_KEY, new Date().toISOString());
}

export type OrganicReferralFollowUpKind = "referral_reason" | "referral_blocker";

export function shouldShowOrganicReferralFollowUp(): {
  attributionId: string;
  kind: OrganicReferralFollowUpKind;
} | null {
  const store = getStorage();
  if (!store) return null;
  const raw = store.getItem(ORGANIC_REFERRAL_PENDING_FOLLOWUP_KEY);
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as {
      attributionId: string;
      kind: OrganicReferralFollowUpKind;
      answered?: boolean;
    };
    if (parsed.answered || !parsed.attributionId || !parsed.kind) return null;
    return { attributionId: parsed.attributionId, kind: parsed.kind };
  } catch {
    return null;
  }
}

export function saveOrganicReferralStatus(
  status: OrganicReferralStatusId,
  entriesInput?: JournalEntry[],
): OrganicReferralRecord {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  const reflectionCount = buildArchiveValueSnapshot(entries).reflectionCount;

  const record: OrganicReferralRecord = {
    id: newId("or"),
    status,
    answeredAt: new Date().toISOString(),
    reflectionCount,
  };

  const rows = readRecords();
  rows.push(record);
  writeRecords(rows);

  trackOrganicReferralStatus({
    status,
    attributionId: record.id,
    reflectionCount,
  });

  markOrganicReferralPromptShown();

  const store = getStorage();
  if (status === "yes") {
    store?.setItem(
      ORGANIC_REFERRAL_PENDING_FOLLOWUP_KEY,
      JSON.stringify({ attributionId: record.id, kind: "referral_reason" }),
    );
  } else if (status === "no") {
    store?.setItem(
      ORGANIC_REFERRAL_PENDING_FOLLOWUP_KEY,
      JSON.stringify({ attributionId: record.id, kind: "referral_blocker" }),
    );
  } else {
    store?.removeItem(ORGANIC_REFERRAL_PENDING_FOLLOWUP_KEY);
  }

  return record;
}

export function saveOrganicReferralReason(
  reason: OrganicReferralReasonId,
  attributionId: string,
): void {
  const rows = readRecords();
  const idx = rows.findIndex((r) => r.id === attributionId);
  if (idx >= 0) {
    rows[idx] = {
      ...rows[idx]!,
      referralReason: reason,
      followUpAnsweredAt: new Date().toISOString(),
    };
    writeRecords(rows);
  }
  trackOrganicReferralReason({ reason, attributionId });
  clearOrganicReferralFollowUp();
}

export function saveReferralBlocker(blocker: ReferralBlockerId, attributionId: string): void {
  const rows = readRecords();
  const idx = rows.findIndex((r) => r.id === attributionId);
  if (idx >= 0) {
    rows[idx] = {
      ...rows[idx]!,
      referralBlocker: blocker,
      followUpAnsweredAt: new Date().toISOString(),
    };
    writeRecords(rows);
  }
  trackReferralBlocker({ blocker, attributionId });
  clearOrganicReferralFollowUp();
}

function clearOrganicReferralFollowUp(): void {
  getStorage()?.removeItem(ORGANIC_REFERRAL_PENDING_FOLLOWUP_KEY);
}

export function dismissOrganicReferralPrompt(): void {
  markOrganicReferralPromptShown();
  clearOrganicReferralFollowUp();
}

export function dismissOrganicReferralFollowUp(): void {
  const store = getStorage();
  if (!store) return;
  const raw = store.getItem(ORGANIC_REFERRAL_PENDING_FOLLOWUP_KEY);
  if (!raw) return;
  try {
    const parsed = JSON.parse(raw) as Record<string, unknown>;
    store.setItem(
      ORGANIC_REFERRAL_PENDING_FOLLOWUP_KEY,
      JSON.stringify({ ...parsed, answered: true }),
    );
  } catch {
    store.removeItem(ORGANIC_REFERRAL_PENDING_FOLLOWUP_KEY);
  }
}

export function readOrganicReferralRecords(): OrganicReferralRecord[] {
  return readRecords().slice().reverse();
}

export function organicReferralReasonLabel(reason: OrganicReferralReasonId): string {
  return ORGANIC_REFERRAL_REASON_LABELS[reason];
}

export function referralBlockerLabel(blocker: ReferralBlockerId): string {
  return REFERRAL_BLOCKER_LABELS[blocker];
}

export function clearOrganicReferralForEval(): void {
  const store = getStorage();
  if (!store) return;
  store.removeItem(ORGANIC_REFERRAL_LAST_SHOWN_KEY);
  store.removeItem(ORGANIC_REFERRAL_RECORDS_KEY);
  store.removeItem(ORGANIC_REFERRAL_PENDING_FOLLOWUP_KEY);
}
