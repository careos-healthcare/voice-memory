import { readLocalEvents, trackLocalEvent } from "@/lib/local-analytics";
import type {
  OrganicReferralReasonId,
  OrganicReferralStatusId,
  ReferralBlockerId,
} from "@/types/organic-referral";

export const ORGANIC_REFERRAL_EVENT_NAMES = {
  status: "organic_referral_status" as const,
  reason: "organic_referral_reason" as const,
  blocker: "referral_blocker" as const,
};

export function trackOrganicReferralStatus(meta: {
  status: OrganicReferralStatusId;
  attributionId: string;
  reflectionCount: number;
}): void {
  trackLocalEvent(ORGANIC_REFERRAL_EVENT_NAMES.status, {
    status: meta.status,
    attributionId: meta.attributionId,
    reflectionCount: String(meta.reflectionCount),
  });
}

export function trackOrganicReferralReason(meta: {
  reason: OrganicReferralReasonId;
  attributionId: string;
}): void {
  trackLocalEvent(ORGANIC_REFERRAL_EVENT_NAMES.reason, {
    reason: meta.reason,
    attributionId: meta.attributionId,
  });
}

export function trackReferralBlocker(meta: {
  blocker: ReferralBlockerId;
  attributionId: string;
}): void {
  trackLocalEvent(ORGANIC_REFERRAL_EVENT_NAMES.blocker, {
    blocker: meta.blocker,
    attributionId: meta.attributionId,
  });
}

export function clearOrganicReferralEventsForEval(): void {
  if (typeof window === "undefined") return;
  try {
    const raw = localStorage.getItem("voicememory_local_events");
    if (!raw) return;
    const names = new Set<string>(Object.values(ORGANIC_REFERRAL_EVENT_NAMES));
    const events = JSON.parse(raw) as Array<{ name: string }>;
    const filtered = events.filter((e) => !names.has(e.name));
    localStorage.setItem("voicememory_local_events", JSON.stringify(filtered));
  } catch {
    /* ignore */
  }
}
