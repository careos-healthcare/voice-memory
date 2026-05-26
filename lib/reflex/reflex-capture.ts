import { detectThinkingOutLoudSignals } from "@/lib/clarity/thinking-out-loud-signals";
import { readLocalEvents } from "@/lib/local-analytics";
import { OPEN_LOOP_EVENTS } from "@/lib/open-loops/open-loop-observation";
import { CALLBACK_LEARNING_EVENTS } from "@/lib/revisit/callback-learning";
import { REFLEX_CONTINUITY_LINES } from "@/lib/reflex/reflex-copy";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type { JournalEntry } from "@/types/journal";
import type { ReflexCaptureResult, ReflexTriggerType } from "@/types/reflex";

const BYPASS_CONFIDENCE = 62;
const RUMINATION_RE = /\bi keep thinking about\b/i;

function isLateNight(now = new Date()): boolean {
  const hour = now.getHours();
  return hour >= 22 || hour < 5;
}

function latestEntry(entries: JournalEntry[]): JournalEntry | null {
  if (entries.length === 0) return null;
  return [...entries].sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
  )[0];
}

function openLoopResurfaceRecent(withinHours = 48): boolean {
  const cutoff = Date.now() - withinHours * 60 * 60 * 1000;
  return readLocalEvents().some(
    (e) =>
      e.name === OPEN_LOOP_EVENTS.resurfacingShown &&
      new Date(e.at).getTime() >= cutoff,
  );
}

function rapidCallbackReopen(): boolean {
  const events = readLocalEvents().slice(-80);
  const opened = events.filter((e) => e.name === CALLBACK_LEARNING_EVENTS.opened);
  const lastOpen = opened[opened.length - 1];
  if (!lastOpen) return false;
  const openMs = new Date(lastOpen.at).getTime();
  const reflected = events.some(
    (e) =>
      e.name === CALLBACK_LEARNING_EVENTS.reflectionAfter &&
      new Date(e.at).getTime() >= openMs,
  );
  return !reflected && Date.now() - openMs < 20 * 60 * 1000;
}

function uncertaintyRepeat(entries: JournalEntry[]): boolean {
  const recent = [...entries]
    .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
    .slice(0, 4);
  let uncertain = 0;
  for (const entry of recent) {
    const signals = detectThinkingOutLoudSignals(entry.transcript);
    if (signals.uncertaintyLikely || signals.conflictLikely) uncertain += 1;
  }
  return uncertain >= 2;
}

export function detectReflexCapture(
  entries: JournalEntry[] = getMemoryEligibleEntries(),
  now = new Date(),
): ReflexCaptureResult {
  const empty: ReflexCaptureResult = {
    likelyReflexMoment: false,
    triggerType: null,
    bypassScore: 0,
    shouldBypassHomepage: false,
    continuityLine: null,
    anchorQuote: null,
    noteId: null,
  };

  const latest = latestEntry(entries);
  if (!latest?.transcript?.trim()) return empty;

  const candidates: Array<{
    type: ReflexTriggerType;
    score: number;
    line: string;
    quote: string | null;
    noteId: string | null;
  }> = [];

  if (openLoopResurfaceRecent()) {
    candidates.push({
      type: "open_loop_resurface",
      score: 28,
      line: REFLEX_CONTINUITY_LINES.open_loop_resurface,
      quote: null,
      noteId: null,
    });
  }

  const conflictSignals = detectThinkingOutLoudSignals(latest.transcript);
  if (conflictSignals.conflictLikely && conflictSignals.confidence >= 48) {
    const snippet = latest.transcript.trim().slice(0, 120);
    candidates.push({
      type: "post_conflict",
      score: 24 + Math.min(20, conflictSignals.confidence / 5),
      line: REFLEX_CONTINUITY_LINES.post_conflict,
      quote: snippet,
      noteId: latest.id,
    });
  }

  if (isLateNight(now)) {
    candidates.push({
      type: "late_night",
      score: 18,
      line: REFLEX_CONTINUITY_LINES.late_night,
      quote: latest.transcript.slice(0, 80),
      noteId: latest.id,
    });
  }

  if (uncertaintyRepeat(entries)) {
    candidates.push({
      type: "uncertainty_repeat",
      score: 26,
      line: REFLEX_CONTINUITY_LINES.uncertainty_repeat,
      quote: latest.transcript.slice(0, 100),
      noteId: latest.id,
    });
  }

  if (rapidCallbackReopen()) {
    candidates.push({
      type: "rapid_callback_reopen",
      score: 30,
      line: REFLEX_CONTINUITY_LINES.rapid_callback_reopen,
      quote: latest.transcript.slice(0, 100),
      noteId: latest.id,
    });
  }

  if (RUMINATION_RE.test(latest.transcript)) {
    const match = latest.transcript.match(RUMINATION_RE);
    candidates.push({
      type: "rumination_phrase",
      score: 32,
      line: REFLEX_CONTINUITY_LINES.rumination_phrase,
      quote: match?.[0] ?? null,
      noteId: latest.id,
    });
  }

  if (candidates.length === 0) return empty;

  const best = [...candidates].sort((a, b) => b.score - a.score)[0];
  const bypassScore = Math.min(100, best.score + (candidates.length > 1 ? 8 : 0));

  return {
    likelyReflexMoment: bypassScore >= 40,
    triggerType: best.type,
    bypassScore,
    shouldBypassHomepage: bypassScore >= BYPASS_CONFIDENCE,
    continuityLine: best.line,
    anchorQuote: best.quote,
    noteId: best.noteId,
  };
}
