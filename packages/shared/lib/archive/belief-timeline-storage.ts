import { theoryToPersonalTheory } from "@/lib/theories/personal-theory-map";
import { ARCHIVE_BELIEF_STATUS_LABEL } from "@/lib/archive/archive-belief-copy";
import {
  emotionalConfidenceLine,
  emotionalWeakenedLine,
} from "@/lib/archive/archive-emotional-copy";
import type { JournalEntry } from "@/types/journal";
import type { BeliefTimelinePoint } from "@/types/belief-timeline";
import type { Theory } from "@/types/theory";

const STORAGE_KEY = "voicememory_belief_timeline";

export interface BeliefTimelineHistoryRecord {
  id: string;
  theoryId: string;
  at: string;
  periodKey: string;
  periodLabel: string;
  confidence: number;
  statusLabel: string;
  note: string;
}

function getStorage(): Storage | null {
  if (typeof window !== "undefined") return localStorage;
  if (typeof globalThis.localStorage !== "undefined") {
    return globalThis.localStorage as Storage;
  }
  return null;
}

function readAll(): BeliefTimelineHistoryRecord[] {
  const store = getStorage();
  if (!store) return [];
  try {
    const raw = store.getItem(STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as BeliefTimelineHistoryRecord[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function writeAll(records: BeliefTimelineHistoryRecord[]): void {
  getStorage()?.setItem(STORAGE_KEY, JSON.stringify(records.slice(-400)));
}

export function readBeliefTimelineHistory(theoryId: string): BeliefTimelineHistoryRecord[] {
  return readAll()
    .filter((r) => r.theoryId === theoryId)
    .sort((a, b) => a.periodKey.localeCompare(b.periodKey));
}

export function clearBeliefTimelineForEval(): void {
  getStorage()?.removeItem(STORAGE_KEY);
}

function newId(prefix: string): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return `${prefix}-${crypto.randomUUID()}`;
  }
  return `${prefix}-${Date.now()}`;
}

export function periodKeyFromIso(iso: string): string {
  const d = new Date(iso);
  if (!Number.isFinite(d.getTime())) return "unknown";
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
}

export function periodLabelFromKey(key: string): string {
  if (key === "unknown") return "Earlier";
  const [y, m] = key.split("-").map(Number);
  if (!y || !m) return key;
  return new Date(y, m - 1, 1).toLocaleString(undefined, { month: "long" });
}

export function deriveTimelineNote(
  current: Theory,
  previous: Theory | null,
): string {
  if (current.whatChanged[0]) {
    const raw = current.whatChanged[0].replace(/\s+/g, " ").trim();
    if (/contradict/i.test(raw)) return "Contradicting evidence appeared";
    if (/confidence increased/i.test(raw)) {
      return emotionalConfidenceLine();
    }
    if (/confidence decreased/i.test(raw)) return emotionalWeakenedLine();
    if (/appeared across/i.test(raw)) return "Evidence growing";
  }

  if (previous) {
    const delta = current.confidence - previous.confidence;
    if (Math.abs(delta) >= 1) {
      return delta > 0 ? emotionalConfidenceLine() : emotionalWeakenedLine();
    }
    if (current.contradictingEvidenceCount > previous.contradictingEvidenceCount) {
      return "Contradicting evidence appeared";
    }
  }

  const personal = theoryToPersonalTheory(current);
  return ARCHIVE_BELIEF_STATUS_LABEL[personal.status];
}

export function recordBeliefTimelineFromTheories(
  theories: Theory[],
  _entries: JournalEntry[],
): void {
  const store = getStorage();
  if (!store) return;

  const existing = readAll();
  const byTheoryMonth = new Map<string, BeliefTimelineHistoryRecord>();

  for (const r of existing) {
    byTheoryMonth.set(`${r.theoryId}:${r.periodKey}`, r);
  }

  const now = new Date().toISOString();
  const periodKey = periodKeyFromIso(now);

  for (const theory of theories) {
    const key = `${theory.id}:${periodKey}`;
    const prevRecords = existing
      .filter((r) => r.theoryId === theory.id)
      .sort((a, b) => b.at.localeCompare(a.at));
    const last = prevRecords[0];
    const personal = theoryToPersonalTheory(theory);
    const statusLabel = ARCHIVE_BELIEF_STATUS_LABEL[personal.status];

    const confidenceChanged =
      !last || Math.abs(last.confidence - theory.confidence) >= 1;
    const statusChanged = last && last.statusLabel !== statusLabel;

    if (last && !confidenceChanged && !statusChanged) continue;

    const note = deriveTimelineNote(
      theory,
      last
        ? ({
            ...theory,
            confidence: last.confidence,
            whatChanged: [],
            contradictingEvidenceCount: 0,
            supportingEvidenceCount: 0,
          } as Theory)
        : null,
    );

    byTheoryMonth.set(key, {
      id: newId("btl"),
      theoryId: theory.id,
      at: now,
      periodKey,
      periodLabel: periodLabelFromKey(periodKey),
      confidence: theory.confidence,
      statusLabel,
      note,
    });
  }

  writeAll([...byTheoryMonth.values()]);
}

export function historyToTimelinePoints(
  records: BeliefTimelineHistoryRecord[],
): BeliefTimelinePoint[] {
  return records.map((r) => ({
    id: r.id,
    periodKey: r.periodKey,
    periodLabel: r.periodLabel,
    confidence: r.confidence,
    statusLabel: r.statusLabel,
    note: r.note,
    whatChanged: r.note,
    evidenceQuoteCount: 0,
    lifeAreas: [] as string[],
    hasContradiction: false,
    hasCostEvidence: false,
    at: r.at,
  }));
}
