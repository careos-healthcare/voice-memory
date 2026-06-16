import { buildArchiveBeliefView } from "@/lib/archive/archive-belief";
import { buildArchiveImplications } from "@/lib/archive/archive-implications";
import { buildArchiveOpenQuestions } from "@/lib/archive/archive-open-question";
import {
  ARCHIVE_PROMPT_CHALLENGE,
  ARCHIVE_PROMPT_GENERAL,
  ARCHIVE_PROMPT_OPEN_UNCERTAIN,
  ARCHIVE_PROMPT_SUPPORT,
  archivePromptMissingArea,
  archivePromptRecentChange,
  FIRST_SESSION_PROMPTS,
  POST_SAVE_FOLLOW_UP_COPY,
} from "@/lib/archive/archive-prompt-copy";
import { buildArchiveSilenceView } from "@/lib/archive/archive-silence";
import { buildBeliefSurvivalView } from "@/lib/archive/belief-survival";
import { readBeliefTimelineHistory } from "@/lib/archive/belief-timeline-storage";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type {
  ArchivePostSaveFollowUp,
  ArchivePostSaveFollowUpId,
  ArchivePrompt,
  ArchivePromptMode,
  ArchivePromptSet,
  ArchivePromptTypeId,
} from "@/types/archive-prompt";
import type { JournalEntry } from "@/types/journal";

const RETURNING_PRIORITY: Record<ArchivePromptTypeId, number> = {
  RECENT_CHANGE_PROMPT: 100,
  OPEN_QUESTION_PROMPT: 90,
  MISSING_AREA_PROMPT: 80,
  SUPPORT_PROMPT: 70,
  CHALLENGE_PROMPT: 60,
  GENERAL_CAPTURE_PROMPT: 50,
};

const DISPLAY_COUNT = 3;

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

function newId(prefix: string): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return `${prefix}-${crypto.randomUUID()}`;
  }
  return `${prefix}-${Date.now()}`;
}

export function hasArchiveAwarePrompts(entriesInput?: JournalEntry[]): boolean {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  return buildArchiveBeliefView(entries) != null && entries.length >= 3;
}

function pushPrompt(
  list: ArchivePrompt[],
  type: ArchivePromptTypeId,
  text: string,
  priority: number,
): void {
  const trimmed = text.trim();
  if (!trimmed) return;
  if (list.some((p) => p.text === trimmed)) return;
  list.push({ id: newId("ap"), type, text: trimmed, priority });
}

function buildFirstSessionPrompts(): ArchivePrompt[] {
  return FIRST_SESSION_PROMPTS.map((text, index) => ({
    id: newId("ap"),
    type: "GENERAL_CAPTURE_PROMPT" as const,
    text,
    priority: FIRST_SESSION_PROMPTS.length - index,
  }));
}

function extractMissingArea(silenceText: string): string | null {
  const match = silenceText.match(/from\s+(\w[\w\s-]*?)\s+in\s+\d+/i);
  if (match?.[1]) return match[1].trim();
  const lately = silenceText.match(/about\s+(\w[\w\s-]*?)\s+lately/i);
  return lately?.[1]?.trim() ?? null;
}

function buildArchiveAwareCandidates(entries: JournalEntry[]): ArchivePrompt[] {
  const out: ArchivePrompt[] = [];
  const belief = buildArchiveBeliefView(entries);
  if (!belief) return out;

  const beliefText = belief.belief.replace(/\s+/g, " ").trim();
  const survival = buildBeliefSurvivalView(entries, { theoryId: belief.theoryId });
  const openQuestions = buildArchiveOpenQuestions(entries);
  const implications = buildArchiveImplications(entries);
  const silence = buildArchiveSilenceView(entries);
  const report = buildTheoryTrackerReport(entries, { persistSnapshots: false });
  const lead = report.all.find((t) => t.id === belief.theoryId) ?? report.all[0];
  const timelineChanges = readBeliefTimelineHistory(belief.theoryId).length;

  const recentChange =
    belief.status === "strengthening" ||
    belief.status === "weakening" ||
    (belief.changeLines.length > 0 && timelineChanges > 0) ||
    (implications?.implications.some((i) =>
      ["STRENGTHENING", "WEAKENING", "NEW_PATTERN"].includes(i.type),
    ) ??
      false);

  if (recentChange) {
    pushPrompt(
      out,
      "RECENT_CHANGE_PROMPT",
      archivePromptRecentChange(belief.status === "strengthening"),
      RETURNING_PRIORITY.RECENT_CHANGE_PROMPT,
    );
  }

  if (openQuestions.length > 0) {
    const q = openQuestions[0]!;
    const text =
      belief.confidence < 52 || belief.status === "under_review"
        ? ARCHIVE_PROMPT_OPEN_UNCERTAIN
        : `${q.lead.replace(/:$/, "")} ${q.text}`.trim();
    pushPrompt(out, "OPEN_QUESTION_PROMPT", text, RETURNING_PRIORITY.OPEN_QUESTION_PROMPT);
  } else if (belief.status === "under_review" || belief.confidence < 52) {
    pushPrompt(
      out,
      "OPEN_QUESTION_PROMPT",
      ARCHIVE_PROMPT_OPEN_UNCERTAIN,
      RETURNING_PRIORITY.OPEN_QUESTION_PROMPT,
    );
  }

  const areaSignal = silence?.signals.find((s) => s.kind === "life_area_absent");
  if (areaSignal) {
    const area = extractMissingArea(areaSignal.text) ?? "that part of your life";
    pushPrompt(
      out,
      "MISSING_AREA_PROMPT",
      archivePromptMissingArea(area),
      RETURNING_PRIORITY.MISSING_AREA_PROMPT,
    );
  } else if (belief.evidence.lifeAreas.length >= 1) {
    const dominant = belief.evidence.lifeAreas[0]!;
    const allAreas = new Set(
      entries.flatMap((e) => [
        ...(e.reflection.recurringThemes ?? []),
      ]),
    );
    if (!allAreas.has(dominant) && entries.length >= 5) {
      pushPrompt(
        out,
        "MISSING_AREA_PROMPT",
        archivePromptMissingArea(dominant),
        RETURNING_PRIORITY.MISSING_AREA_PROMPT,
      );
    }
  }

  pushPrompt(
    out,
    "SUPPORT_PROMPT",
    ARCHIVE_PROMPT_SUPPORT(beliefText),
    RETURNING_PRIORITY.SUPPORT_PROMPT,
  );

  pushPrompt(
    out,
    "CHALLENGE_PROMPT",
    ARCHIVE_PROMPT_CHALLENGE(beliefText),
    RETURNING_PRIORITY.CHALLENGE_PROMPT,
  );

  if (survival && survival.contradictionsSurvived > 0 && !out.some((p) => p.type === "CHALLENGE_PROMPT")) {
    pushPrompt(
      out,
      "CHALLENGE_PROMPT",
      ARCHIVE_PROMPT_CHALLENGE(beliefText),
      RETURNING_PRIORITY.CHALLENGE_PROMPT - 1,
    );
  }

  if (lead?.contradictingEvidence.length && !out.some((p) => p.type === "CHALLENGE_PROMPT")) {
    pushPrompt(
      out,
      "CHALLENGE_PROMPT",
      ARCHIVE_PROMPT_CHALLENGE(beliefText),
      RETURNING_PRIORITY.CHALLENGE_PROMPT,
    );
  }

  pushPrompt(
    out,
    "GENERAL_CAPTURE_PROMPT",
    ARCHIVE_PROMPT_GENERAL,
    RETURNING_PRIORITY.GENERAL_CAPTURE_PROMPT,
  );

  return out
    .slice()
    .sort((a, b) => b.priority - a.priority);
}

/**
 * Build all archive-aware or first-session prompts — no LLM.
 */
export function buildArchivePrompts(
  entriesInput?: JournalEntry[],
): ArchivePromptSet {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  const mode: ArchivePromptMode = hasArchiveAwarePrompts(entries)
    ? "archive_aware"
    : "first_session";

  const prompts =
    mode === "first_session"
      ? buildFirstSessionPrompts()
      : buildArchiveAwareCandidates(entries);

  return { mode, prompts };
}

function rotateSlice<T>(items: T[], count: number, offset: number): T[] {
  if (items.length === 0) return [];
  const start = offset % items.length;
  const picked: T[] = [];
  for (let i = 0; i < Math.min(count, items.length); i += 1) {
    picked.push(items[(start + i) % items.length]!);
  }
  return picked;
}

/** Up to 3 prompts for Low Effort Mode — no scrolling wall. */
export function pickArchiveDisplayPrompts(
  set: ArchivePromptSet,
  options?: { refreshIndex?: number; count?: number },
): ArchivePrompt[] {
  const count = options?.count ?? DISPLAY_COUNT;
  const offset = options?.refreshIndex ?? 0;
  if (set.prompts.length <= count) return set.prompts.slice(0, count);
  return rotateSlice(set.prompts, count, offset);
}

export function buildPostSaveFollowUp(
  entriesInput?: JournalEntry[],
): ArchivePostSaveFollowUp {
  const entries = eligible(entriesInput ?? getMemoryEligibleEntries());
  const belief = buildArchiveBeliefView(entries);

  let id: ArchivePostSaveFollowUpId = "anything_else";
  if (belief?.status === "strengthening" || belief?.status === "weakening") {
    id = "support_or_challenge";
  } else if (belief && belief.confidence < 55) {
    id = "more_context";
  }

  return {
    id,
    text: POST_SAVE_FOLLOW_UP_COPY[id],
  };
}
