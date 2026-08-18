import {
  gateContinuityLine,
  gateContinuityQuote,
} from "@/lib/continuity/continuity-quality-gate";
import {
  resolveEarlyPreMicLine,
  resolveSurfacedPreMicLine,
} from "@/lib/continuity/memory-starts-immediately";
import {
  isJunkReflectionTranscript,
  isPrimarySurfacedReflection,
} from "@/lib/reflection/reflection-quality-gate";
import { buildReturnThreads } from "@/lib/continuity/return-threads";
import { daysBetweenKeys, toDayKey } from "@/lib/dates";
import { sanitizeUserFacingObservation } from "@/lib/product/human-continuity-ui";
import type { ReturnThread, ReturnThreadType } from "@/types/return-thread";
import type { JournalEntry } from "@/types/journal";

const BANNED_LINE_RE =
  /\b(speaker expresses|the speaker|mood tracker|dominant mood|emotional trend|emotional intensity|intensity trend|ai analysis|analyzed your|therapy|diagnosis|coping plan|you should|you need to|try to|i recommend)\b/i;

function formatQuote(text: string): string {
  const trimmed = text.trim().slice(0, 140);
  if (!trimmed) return "";
  if (trimmed.startsWith('"') && trimmed.endsWith('"')) return trimmed;
  return `"${trimmed}"`;
}

function gapLabel(days: number): string {
  if (days <= 0) return "again tonight";
  if (days === 1) return "again the next day";
  if (days < 7) return `again after ${days} days`;
  if (days < 21) return `${days} days later, this came back`;
  const weeks = Math.round(days / 7);
  return weeks === 1 ? "about a week later" : `${weeks} weeks later, this came back differently`;
}

export function isAllowedContinuityLine(line: string): boolean {
  const trimmed = line.trim();
  if (!trimmed || trimmed.length > 220) return false;
  if (BANNED_LINE_RE.test(trimmed)) return false;
  if (!gateContinuityLine(trimmed)) return false;
  return sanitizeUserFacingObservation(trimmed) !== null || !BANNED_LINE_RE.test(trimmed);
}

export function quoteFromEntry(entry: JournalEntry): string {
  if (entry.reflection.exactLanguagePattern?.trim()) {
    const q = gateContinuityQuote(entry.reflection.exactLanguagePattern.trim().slice(0, 140));
    if (q) return q;
  }
  const transcript = entry.transcript?.trim();
  if (transcript && !isJunkReflectionTranscript(transcript)) {
    const slice = transcript.slice(0, 140);
    const raw = transcript.length > 140 ? `${slice}…` : slice;
    return gateContinuityQuote(raw) ?? "";
  }
  const obs =
    entry.reflection.concreteObservation?.trim() ??
    entry.reflection.patternObservations?.find((o) => o.trim())?.trim();
  if (obs) return gateContinuityQuote(obs.slice(0, 140)) ?? "";
  return "";
}

/** User-facing continuity line for a return thread. */
export function buildContinuityLineForThread(thread: {
  type: ReturnThreadType;
  anchorQuote: string;
  latestQuote: string;
  gapDays?: number;
  contextLabel?: string;
  appearances: number;
}): string {
  const gap = thread.gapDays ?? 0;
  const anchor = formatQuote(thread.anchorQuote);
  const latest = formatQuote(thread.latestQuote);
  const label = thread.contextLabel?.trim();

  let line = "";

  switch (thread.type) {
    case "repeated_phrase":
      line =
        thread.appearances >= 3
          ? `You kept circling ${label ? `"${label}"` : "this phrase"}.`
          : `You mentioned this again ${gapLabel(gap)}.`;
      break;
    case "unresolved_problem":
      line = "This thread still feels unfinished.";
      break;
    case "recurring_person":
      line = label
        ? `You returned to ${label} in different words.`
        : "You returned to the same person in different words.";
      break;
    case "contradiction":
      line = "You came back to this in different words.";
      break;
    case "changed_position":
      if (anchor && latest && anchor !== latest) {
        line = `Earlier: ${anchor} Now: ${latest}`;
      } else {
        line = "Something changed in how you said this.";
      }
      break;
    case "silence_then_return":
      line =
        gap >= 5
          ? `You stopped talking about this for ${gap} days.`
          : "You stopped talking about this for a while.";
      break;
    case "emotional_reversal":
      line =
        gap >= 7
          ? `Three weeks later, this came back differently.`
          : "This came back with a different tone in your words.";
      break;
    case "recurring_uncertainty":
      line = label
        ? `The same uncertainty about ${label} showed up again.`
        : "The same uncertainty showed up again.";
      break;
    default:
      line = "You mentioned this again.";
  }

  if (!isAllowedContinuityLine(line)) {
    line = "This came back.";
  }
  return line;
}

/** Sharpest single line for homepage / pre-mic — quote-led when possible. */
export function pickHomepageContinuityLine(
  threads: ReturnThread[],
  entries: JournalEntry[],
): string | null {
  const sorted = [...threads].sort((a, b) => {
    const gapA = a.gapDays ?? 0;
    const gapB = b.gapDays ?? 0;
    if (gapB !== gapA) return gapB - gapA;
    return b.appearances - a.appearances;
  });

  for (const thread of sorted) {
    if (!thread.continuityLine || !isAllowedContinuityLine(thread.continuityLine)) continue;
    if (!gateContinuityQuote(thread.anchorQuote) && !gateContinuityQuote(thread.latestQuote)) {
      continue;
    }
    const short =
      thread.continuityLine.length <= 72
        ? thread.continuityLine
        : thread.continuityLine.slice(0, 69) + "…";
    return gateContinuityLine(short) ?? short;
  }

  return null;
}

export function gapDaysBetween(firstIso: string, lastIso: string): number {
  return Math.max(0, daysBetweenKeys(toDayKey(firstIso), toDayKey(lastIso)));
}

/** Single quote-led line before the mic — max one, no fake or generic fallbacks. */
export function preMicContinuityLine(entries: JournalEntry[]): string | null {
  return resolveEarlyPreMicLine(entries);
}

/** Homepage / mic continuity — hard-gated, never quotes junk transcripts. */
export function surfacedContinuityLine(
  line: string | null | undefined,
  entries: JournalEntry[],
): string | null {
  return resolveSurfacedPreMicLine(line, entries);
}
