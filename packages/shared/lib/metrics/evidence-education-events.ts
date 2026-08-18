import { readLocalEvents, trackLocalEvent } from "@/lib/local-analytics";
import type { EvidenceEducationTrigger } from "@/lib/archive/evidence-education";

export const WHY_EVIDENCE_MATTERS_SEEN = "why_evidence_matters_seen";

export function trackWhyEvidenceMattersSeen(meta: {
  reflectionCount: number;
  trigger: EvidenceEducationTrigger;
}): void {
  trackLocalEvent(WHY_EVIDENCE_MATTERS_SEEN, {
    reflectionCount: String(meta.reflectionCount),
    trigger: meta.trigger,
  });
}

export function countWhyEvidenceMattersSeen(): number {
  return readLocalEvents().filter((e) => e.name === WHY_EVIDENCE_MATTERS_SEEN).length;
}

export function clearWhyEvidenceMattersSeenForEval(): void {
  if (typeof window === "undefined") return;
  const raw = localStorage.getItem("voicememory_local_events");
  if (!raw) return;
  try {
    const events = JSON.parse(raw) as Array<{ name: string }>;
    const filtered = events.filter((e) => e.name !== WHY_EVIDENCE_MATTERS_SEEN);
    localStorage.setItem("voicememory_local_events", JSON.stringify(filtered));
  } catch {
    /* ignore */
  }
}
