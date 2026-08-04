import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { buildRetentionLoopReport } from "@/lib/retention/retention-loops";
import { buildDurableCallbacksReport } from "@/lib/refinement/durable-callbacks";
import { calibratePrimaryNote } from "@/lib/refinement/silence-calibration";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type { MemoryNote } from "@/types/memory-note";
import type { ArchiveLandmark, ArchiveLandmarkReport } from "@/types/archive-permanence-layer";

export const LANDMARK_COPY = {
  returnedManyTimes: "You came back to this many times.",
  stayedWithYou: "This saved moment stayed with you.",
  returnedMonthsLater: "You returned here months later.",
} as const;

export const LANDMARK_FORBIDDEN = [
  "most important",
  "top memory",
  "best reflection",
  "achievement",
  "milestone unlocked",
  "rank",
] as const;

const MIN_ARCHIVE_SPAN_DAYS = 180;
const MIN_DEEP_ENTRIES = 40;
const MAX_LANDMARKS = 2;
const SHOW_COOLDOWN_DAYS = 42;

const LANDMARK_KEY = "voicememory_archive_landmarks";

function isBrowser(): boolean {
  return typeof window !== "undefined";
}

function archiveEligible(entries: JournalEntry[]): boolean {
  if (entries.length >= MIN_DEEP_ENTRIES) return true;
  const sorted = [...entries].sort(
    (a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime(),
  );
  if (sorted.length < 4) return false;
  const span = daysBetweenKeys(toDayKey(sorted[0].createdAt), toDayKey(sorted[sorted.length - 1].createdAt));
  return span >= MIN_ARCHIVE_SPAN_DAYS;
}

function passesLandmarkCopy(text: string): boolean {
  const lower = text.toLowerCase();
  return !LANDMARK_FORBIDDEN.some((phrase) => lower.includes(phrase));
}

function readShownIds(): string[] {
  if (!isBrowser()) return [];
  try {
    const raw = localStorage.getItem(LANDMARK_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw) as Array<{ id: string; at: number }>;
    const cutoff = Date.now() - SHOW_COOLDOWN_DAYS * 86400000;
    return parsed.filter((row) => row.at >= cutoff).map((row) => row.id);
  } catch {
    return [];
  }
}

function markShown(ids: string[]): void {
  if (!isBrowser()) return;
  const rows = ids.map((id) => ({ id, at: Date.now() }));
  localStorage.setItem(LANDMARK_KEY, JSON.stringify(rows.slice(-6)));
}

/** Build sparse archive landmarks tied to durable revisit behavior. */
export function buildArchiveLandmarkReport(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): ArchiveLandmarkReport {
  const eligible = archiveEligible(entries);
  if (!eligible) {
    return { generatedAt: new Date().toISOString(), hasData: false, landmarks: [], eligible: false };
  }

  const loops = buildRetentionLoopReport();
  const durable = buildDurableCallbacksReport(entries);
  const landmarks: ArchiveLandmark[] = [];

  for (const row of loops.notesCausingRevisits) {
    if (row.oldEntryOpens + row.clicks < 2) continue;
    const text =
      row.oldEntryOpens >= 3
        ? LANDMARK_COPY.returnedManyTimes
        : LANDMARK_COPY.stayedWithYou;
    if (!passesLandmarkCopy(text)) continue;

    landmarks.push({
      id: `landmark-revisit-${row.noteId}`,
      text,
      entryId: row.noteId,
      callbackId: row.noteId,
      strength: 70 + row.oldEntryOpens * 4 + row.clicks * 2,
      evidence: `${row.oldEntryOpens} opens · ${row.clicks} clicks`,
    });
  }

  for (const link of loops.revisitsCausingReflections.filter((l) => l.reflectionEntryId)) {
    const text = LANDMARK_COPY.returnedMonthsLater;
    if (!passesLandmarkCopy(text)) continue;
    landmarks.push({
      id: `landmark-reflect-${link.entryId}`,
      text,
      entryId: link.entryId,
      callbackId: link.noteId,
      strength: 78,
      evidence: link.sources || "Revisit led to a saved moment",
    });
  }

  for (const leader of durable.leaders.slice(0, 4)) {
    const text = LANDMARK_COPY.stayedWithYou;
    if (!passesLandmarkCopy(text)) continue;
    landmarks.push({
      id: `landmark-durable-${leader.id}`,
      text,
      entryId: leader.id,
      callbackId: leader.id,
      strength: leader.durableScore,
      evidence: `${leader.revisits} revisits · residue ${leader.durableScore}`,
    });
  }

  const seen = new Set<string>();
  const unique = landmarks
    .filter((row) => {
      const key = row.entryId;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    })
    .sort((a, b) => b.strength - a.strength)
    .slice(0, MAX_LANDMARKS);

  return {
    generatedAt: new Date().toISOString(),
    hasData: unique.length > 0,
    landmarks: unique,
    eligible,
  };
}

function landmarkToNote(landmark: ArchiveLandmark): MemoryNote {
  return {
    id: landmark.id,
    text: landmark.text,
    category: "returned",
    confidence: landmark.strength,
    entryId: landmark.entryId,
    pastEntryId: landmark.entryId,
  };
}

/** Pick at most 1–2 visible landmarks, silence-calibrated. */
export function pickArchiveLandmarkNotes(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): MemoryNote[] {
  const report = buildArchiveLandmarkReport(entries);
  if (!report.eligible || report.landmarks.length === 0) return [];

  const shown = new Set(readShownIds());
  const notes: MemoryNote[] = [];

  for (const landmark of report.landmarks) {
    if (shown.has(landmark.id)) continue;
    const calibrated = calibratePrimaryNote([landmarkToNote(landmark)], entries, "memory");
    if (calibrated) notes.push(calibrated);
    if (notes.length >= MAX_LANDMARKS) break;
  }

  if (notes.length > 0) {
    markShown(notes.map((n) => n.id));
  }

  return notes;
}

export function pickPrimaryArchiveLandmark(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
): MemoryNote | null {
  return pickArchiveLandmarkNotes(entries)[0] ?? null;
}
