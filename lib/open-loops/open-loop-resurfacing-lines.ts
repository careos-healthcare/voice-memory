import { passesResurfacingGenericityGate } from "@/lib/resurfacing/genericity-filter";
import { formatEntryDate } from "@/lib/utils";
import { getEntry } from "@/lib/storage";
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

function quoteSnippet(text: string, max = 52): string {
  const compact = text.replace(/\s+/g, " ").trim();
  if (compact.length <= max) return compact;
  return `${compact.slice(0, max - 1)}…`;
}

interface LineCandidate {
  line: string;
  priority: number;
  evidenceBacked: boolean;
}

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

/** Quote-anchored lines first — personally specific, not generic coaching. */
function buildSpecificCandidates(loop: OpenLoop): LineCandidate[] {
  const candidates: LineCandidate[] = [];
  const anchor = quoteSnippet(loop.strongestAnchorPhrase, 56);
  const step = quoteSnippet(loop.userNextStep, 44);
  const sourceEntry = getEntry(loop.sourceEntryId);
  const dateLabel = sourceEntry ? formatEntryDate(sourceEntry.createdAt) : null;

  if (anchor.length >= 14) {
    candidates.push({
      line: dateLabel
        ? `From ${dateLabel}: "${anchor}" — you kept this thread open.`
        : `From this reflection: "${anchor}" — you kept this thread open.`,
      priority: 96,
      evidenceBacked: true,
    });
  }

  if (step.length >= 10) {
    candidates.push({
      line: `You wrote to remember: "${step}"`,
      priority: 94,
      evidenceBacked: true,
    });
  }

  if (anchor.length >= 14 && step.length >= 10) {
    candidates.push({
      line: `"${anchor}" — and you noted: "${step}"`,
      priority: 93,
      evidenceBacked: true,
    });
  }

  return candidates;
}

function buildTemporalCandidates(loop: OpenLoop, now = Date.now()): LineCandidate[] {
  const candidates: LineCandidate[] = [];
  const gapDays = daysBetweenLastTwoMentions(loop);
  const concern = loop.concernLabel?.trim() ?? "";

  if (loop.status === "softened") {
    candidates.push({
      line: "You once marked this as softened.",
      priority: 88,
      evidenceBacked: true,
    });
  }

  if (shouldAllowAbsenceResurfacing(loop)) {
    candidates.push({
      line: "This returned after being absent for a while.",
      priority: 82,
      evidenceBacked: true,
    });
  }

  if (gapDays !== null && gapDays >= 2) {
    candidates.push({
      line: `You mentioned this again after ${gapDays} days.`,
      priority: 84,
      evidenceBacked: true,
    });
  }

  if (loop.recurrenceCount >= 2 && loop.relatedEntryIds.length >= 2) {
    const anchor = quoteSnippet(loop.strongestAnchorPhrase, 40);
    candidates.push({
      line:
        anchor.length >= 14
          ? `This thread — "${anchor}" — showed up in another reflection.`
          : "This concern has appeared across multiple reflections.",
      priority: 80,
      evidenceBacked: anchor.length >= 14,
    });
  }

  if (distinctAnchorWording(loop)) {
    candidates.push({
      line: "You came back to this in different words.",
      priority: 76,
      evidenceBacked: true,
    });
  }

  if (concern && UNCERTAIN_CONCERN_RE.test(concern) && loop.strongestAnchorPhrase.length >= 14) {
    const topic = quoteSnippet(loop.strongestAnchorPhrase, 32);
    candidates.push({
      line: `"${topic}" — this thread keeps circling back.`,
      priority: 78,
      evidenceBacked: true,
    });
  }

  if (loop.status === "open" && daysSinceLastMention(loop, now) >= 3 && loop.recurrenceCount >= 2) {
    candidates.push({
      line: "This thread still feels unfinished.",
      priority: 62,
      evidenceBacked: true,
    });
  }

  return candidates;
}

function buildAllCandidates(loop: OpenLoop, now = Date.now()): LineCandidate[] {
  if (loop.status === "closed") return [];
  return [...buildSpecificCandidates(loop), ...buildTemporalCandidates(loop, now)];
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
