import { passesResurfacingGenericityGate } from "@/lib/resurfacing/genericity-filter";
import { shouldAllowAbsenceResurfacing } from "@/lib/open-loops/open-loop-silence";
import type { OpenLoop } from "@/types/open-loop";

const UNCERTAIN_CONCERN_RE = /\b(uncertain|unsure|waiting|avoid)\b/i;

function daysBetween(isoA: string, isoB: string): number {
  const ms = Math.abs(new Date(isoB).getTime() - new Date(isoA).getTime());
  return Math.round(ms / (1000 * 60 * 60 * 24));
}

function daysSinceLastMention(loop: OpenLoop, now = Date.now()): number {
  const last = new Date(loop.lastMentionedAt).getTime();
  if (!Number.isFinite(last)) return 0;
  return Math.max(0, Math.round((now - last) / (1000 * 60 * 60 * 24)));
}

function daysBetweenLastTwoMentions(loop: OpenLoop): number | null {
  const history = [...(loop.mentionHistory ?? [])].sort(
    (a, b) => new Date(a).getTime() - new Date(b).getTime(),
  );
  if (history.length < 2) return null;
  return daysBetween(history[history.length - 2], history[history.length - 1]);
}

function distinctAnchorWording(loop: OpenLoop): boolean {
  const phrases = loop.anchorPhrases.map((p) => p.trim().toLowerCase()).filter(Boolean);
  return new Set(phrases).size >= 2;
}

interface LineCandidate {
  line: string;
  priority: number;
  evidenceBacked: boolean;
}

/** User-marked or time-anchored lines — allowed without genericity false positives. */
const TRUSTED_CONTINUITY_LINES = new Set([
  "You once marked this as softened.",
]);

function passesContinuityGate(line: string): boolean {
  if (TRUSTED_CONTINUITY_LINES.has(line)) return true;
  return passesResurfacingGenericityGate(line, undefined, { evidenceBacked: true });
}

function pickBestLine(candidates: LineCandidate[]): string | null {
  const ranked = candidates
    .filter((row) => row.evidenceBacked)
    .filter((row) => passesContinuityGate(row.line))
    .sort((a, b) => b.priority - a.priority);

  return ranked[0]?.line ?? null;
}

/** At most one restrained continuity line — evidence-backed, no clinical framing. */
export function pickOpenLoopResurfacingLine(loop: OpenLoop, now = Date.now()): string | null {
  return pickBestLine(buildAllCandidates(loop, now));
}

export interface OpenLoopResurfacingCandidate {
  line: string;
  priority: number;
  evidenceBacked: boolean;
  passesGate: boolean;
  suppressed: boolean;
  shown: boolean;
}

function buildAllCandidates(loop: OpenLoop, now = Date.now()): LineCandidate[] {
  if (loop.status === "closed") return [];

  const candidates: LineCandidate[] = [];
  const gapDays = daysBetweenLastTwoMentions(loop);
  const concern = loop.concernLabel?.trim() ?? "";

  if (loop.status === "softened") {
    candidates.push({
      line: "You once marked this as softened.",
      priority: 94,
      evidenceBacked: true,
    });
  }

  if (shouldAllowAbsenceResurfacing(loop)) {
    candidates.push({
      line: "This returned after being absent for a while.",
      priority: 88,
      evidenceBacked: true,
    });
  }

  if (gapDays !== null && gapDays >= 2) {
    candidates.push({
      line: `You mentioned this again after ${gapDays} days.`,
      priority: 85,
      evidenceBacked: true,
    });
  }

  if (loop.recurrenceCount >= 2 && loop.relatedEntryIds.length >= 2) {
    candidates.push({
      line: "This concern has appeared across multiple reflections.",
      priority: 80,
      evidenceBacked: true,
    });
  }

  if (distinctAnchorWording(loop)) {
    candidates.push({
      line: "You came back to this in different words.",
      priority: 78,
      evidenceBacked: true,
    });
  }

  if (concern && UNCERTAIN_CONCERN_RE.test(concern)) {
    candidates.push({
      line: `This feeling seems to return around ${concern.toLowerCase()}.`,
      priority: 76,
      evidenceBacked: true,
    });
  }

  if (loop.status === "open" && daysSinceLastMention(loop, now) >= 3) {
    candidates.push({
      line: "This thread still feels unfinished.",
      priority: 70,
      evidenceBacked: loop.recurrenceCount >= 2,
    });
  }

  return candidates;
}

/** Debug/validation audit — shown line plus suppressed generic candidates. */
export function auditOpenLoopResurfacing(loop: OpenLoop, now = Date.now()): {
  shown: string | null;
  candidates: OpenLoopResurfacingCandidate[];
} {
  const raw = buildAllCandidates(loop, now);
  const shown = pickBestLine(raw);

  const candidates: OpenLoopResurfacingCandidate[] = raw.map((row) => {
    const passesGate = row.evidenceBacked && passesContinuityGate(row.line);
    const suppressed = row.evidenceBacked && !passesGate;
    return {
      line: row.line,
      priority: row.priority,
      evidenceBacked: row.evidenceBacked,
      passesGate,
      suppressed,
      shown: shown === row.line,
    };
  });

  return { shown, candidates };
}
