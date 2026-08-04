import { buildArchiveValueSnapshot } from "@/lib/product/archive-value-progress";
import { findThemeEcho } from "@/lib/blind-spots/mini-wow";
import { buildEmergingPatterns } from "@/lib/blind-spots/emerging-patterns";
import { buildPatternCandidatesRelaxed } from "@/lib/patterns/pattern-engine";
import { buildPhraseMemory } from "@/lib/patterns/phrase-memory";
import { buildTheoryTrackerReport } from "@/lib/theories/theory-generation";
import { clampConfidence } from "@/lib/theories/theory-confidence-movement";
import {
  IMMEDIATE_ENGAGEMENT_HEADING,
  IMMEDIATE_FOLLOWUP_BY_KIND,
  IMMEDIATE_NOTICE_CATEGORY,
} from "@/lib/archive/immediate-engagement-copy";
import type { ImmediateEngagementPayload, ImmediateNoticeKind } from "@/types/immediate-engagement";
import type { JournalEntry } from "@/types/journal";

function eligible(entries: JournalEntry[]): JournalEntry[] {
  return entries.filter((e) => e.reflectionPending !== true);
}

function newId(prefix: string): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return `${prefix}-${crypto.randomUUID()}`;
  }
  return `${prefix}-${Date.now()}`;
}

function trimLine(text: string, max = 140): string {
  const n = text.replace(/\s+/g, " ").trim();
  return n.length <= max ? n : `${n.slice(0, max - 1)}…`;
}

function includesNewEntry(entryIds: string[], newEntryId: string): boolean {
  return entryIds.includes(newEntryId);
}

function repeatedPhraseNotice(
  entries: JournalEntry[],
  newEntryId: string,
): { kind: ImmediateNoticeKind; detail: string } | null {
  const phrase = buildPhraseMemory(entries).find(
    (p) =>
      p.entryIds.length >= 2 &&
      p.count >= 2 &&
      includesNewEntry(p.entryIds, newEntryId) &&
      p.phrase.length >= 6,
  );
  if (phrase) {
    return {
      kind: "repeated_phrase",
      detail: trimLine(`“${phrase.phrase}” showed up again in your words.`),
    };
  }

  const patterns = buildPatternCandidatesRelaxed(entries, { limit: 8 });
  const phrasePattern = patterns.find(
    (p) =>
      p.type === "repeated_phrase" &&
      includesNewEntry(p.entryIds, newEntryId) &&
      p.entryIds.length >= 2,
  );
  if (phrasePattern?.evidence[0]?.phrase) {
    return {
      kind: "repeated_phrase",
      detail: trimLine(`“${phrasePattern.evidence[0].phrase}” echoed across saved moments.`),
    };
  }

  const newEntry = entries.find((e) => e.id === newEntryId);
  if (newEntry?.reflection.exactLanguagePattern?.trim()) {
    const needle = newEntry.reflection.exactLanguagePattern.trim().toLowerCase();
    const prior = entries.filter((e) => e.id !== newEntryId);
    const hit = prior.some((e) => e.transcript.toLowerCase().includes(needle.slice(0, 24)));
    if (hit && needle.length >= 8) {
      return {
        kind: "repeated_phrase",
        detail: trimLine(`Similar wording to an earlier saved moment: “${needle}”.`),
      };
    }
  }

  return null;
}

function possiblePatternNotice(
  entries: JournalEntry[],
  newEntryId: string,
): { kind: ImmediateNoticeKind; detail: string } | null {
  const emerging = buildEmergingPatterns(entries).find((p) =>
    p.evidenceQuotes.some((q) => q.entryId === newEntryId),
  );
  if (emerging) {
    return {
      kind: "possible_pattern",
      detail: trimLine(emerging.hypothesis || emerging.label),
    };
  }

  const pattern = buildPatternCandidatesRelaxed(entries, { limit: 6 }).find(
    (p) =>
      includesNewEntry(p.entryIds, newEntryId) &&
      p.entryIds.length >= 2 &&
      p.type !== "repeated_phrase",
  );
  if (pattern) {
    const line =
      pattern.evidence[0]?.phrase ||
      pattern.specificity.whyThisFeltSpecific[0] ||
      "A repeat may be forming across your archive.";
    return { kind: "possible_pattern", detail: trimLine(line) };
  }

  const theme = findThemeEcho(entries);
  if (theme && includesNewEntry(theme.entryIds, newEntryId)) {
    return {
      kind: "possible_pattern",
      detail: trimLine(`Theme “${theme.theme}” may be repeating.`),
    };
  }

  return null;
}

function leadTouchesNewEntry(
  lead: NonNullable<ReturnType<typeof buildTheoryTrackerReport>["all"][0]>,
  newEntryId: string,
): boolean {
  return (
    lead.supportingEvidence.some((q) => q.entryId === newEntryId) ||
    lead.contradictingEvidence.some((q) => q.entryId === newEntryId)
  );
}

function theoryMovementNotice(
  entriesBefore: JournalEntry[],
  entriesAfter: JournalEntry[],
  newEntryId: string,
): { kind: ImmediateNoticeKind; detail: string } | null {
  const reportBefore = buildTheoryTrackerReport(entriesBefore, { persistSnapshots: false });
  const reportAfter = buildTheoryTrackerReport(entriesAfter, { persistSnapshots: true });
  const lead = reportAfter.all[0];
  if (!lead) return null;

  const leadBefore = reportBefore.all.find((t) => t.id === lead.id);
  const supportGrew =
    lead.supportingEvidenceCount > (leadBefore?.supportingEvidenceCount ?? 0);
  if (!supportGrew && !leadTouchesNewEntry(lead, newEntryId)) return null;

  const delta = lead.confidenceDelta;
  if (lead.previousConfidence !== undefined && Math.abs(delta) >= 1) return null;

  return {
    kind: "theory_movement",
    detail: trimLine(
      `Archive linked this saved moment to a working theory (${trimLine(lead.statement, 60)}).`,
    ),
  };
}

function confidenceChangeNotice(
  entriesBefore: JournalEntry[],
  entriesAfter: JournalEntry[],
  newEntryId: string,
): { kind: ImmediateNoticeKind; detail: string } | null {
  const reportBefore = buildTheoryTrackerReport(entriesBefore, { persistSnapshots: false });
  const reportAfter = buildTheoryTrackerReport(entriesAfter, { persistSnapshots: true });
  const lead = reportAfter.all[0];
  if (!lead || lead.previousConfidence === undefined) return null;

  const delta = lead.confidenceDelta;
  if (Math.abs(delta) < 1) return null;

  const leadBefore = reportBefore.all.find((t) => t.id === lead.id);
  const supportGrew =
    lead.supportingEvidenceCount > (leadBefore?.supportingEvidenceCount ?? 0);
  if (!supportGrew && !leadTouchesNewEntry(lead, newEntryId)) return null;

  const prev = clampConfidence(lead.previousConfidence);
  const curr = clampConfidence(lead.confidence);
  const direction = delta > 0 ? "increased" : "decreased";
  return {
    kind: "confidence_change",
    detail: trimLine(
      `Working theory confidence ${direction}: ${prev}% → ${curr}% (${trimLine(lead.statement, 60)}).`,
    ),
  };
}

function contradictionNotice(
  entriesBefore: JournalEntry[],
  entriesAfter: JournalEntry[],
  newEntryId: string,
): { kind: ImmediateNoticeKind; detail: string } | null {
  const before = buildArchiveValueSnapshot(entriesBefore);
  const after = buildArchiveValueSnapshot(entriesAfter);
  if (after.contradictionCount > before.contradictionCount) {
    return {
      kind: "contradiction",
      detail: "Your archive now contains evidence pointing in two directions.",
    };
  }

  const pattern = buildPatternCandidatesRelaxed(entriesAfter, { limit: 6 }).find(
    (p) => p.type === "contradiction" && includesNewEntry(p.entryIds, newEntryId),
  );
  if (pattern) {
    return {
      kind: "contradiction",
      detail: trimLine(
        pattern.evidence[0]?.phrase || "Expectations and later words may not fully align.",
      ),
    };
  }

  const lead = buildTheoryTrackerReport(entriesAfter, { persistSnapshots: false }).all[0];
  const leadTouchesNew =
    lead?.contradictingEvidence.some((q) => q.entryId === newEntryId) ||
    lead?.supportingEvidence.some((q) => q.entryId === newEntryId);
  if (lead && lead.contradictingEvidenceCount > 0 && leadTouchesNew) {
    return {
      kind: "contradiction",
      detail: "Recent saved moments may pull in different directions on the same thread.",
    };
  }

  return null;
}

function newEvidenceNotice(
  entriesBefore: JournalEntry[],
  entriesAfter: JournalEntry[],
): { kind: ImmediateNoticeKind; detail: string } | null {
  const beforeCount = eligible(entriesBefore).length;
  const afterCount = eligible(entriesAfter).length;
  if (afterCount <= beforeCount) return null;

  const reportAfter = buildTheoryTrackerReport(entriesAfter, { persistSnapshots: false });
  const lead = reportAfter.all[0];
  if (lead) {
    return {
      kind: "new_evidence",
      detail: trimLine(
        `${lead.supportingEvidenceCount} supporting moment${lead.supportingEvidenceCount === 1 ? "" : "s"} in archive for this thread.`,
      ),
    };
  }

  return {
    kind: "new_evidence",
    detail: `Your archive now has ${afterCount} saved moment${afterCount === 1 ? "" : "s"} to compare.`,
  };
}

function pickNotice(
  entriesAfter: JournalEntry[],
  newEntryId: string,
): { kind: ImmediateNoticeKind; detail: string } {
  const entriesBefore = entriesAfter.filter((e) => e.id !== newEntryId);

  return (
    repeatedPhraseNotice(entriesAfter, newEntryId) ??
    possiblePatternNotice(entriesAfter, newEntryId) ??
    theoryMovementNotice(entriesBefore, entriesAfter, newEntryId) ??
    confidenceChangeNotice(entriesBefore, entriesAfter, newEntryId) ??
    contradictionNotice(entriesBefore, entriesAfter, newEntryId) ??
    newEvidenceNotice(entriesBefore, entriesAfter) ?? {
      kind: "new_evidence",
      detail: "Your archive is actively comparing this saved moment against prior evidence.",
    }
  );
}

export function buildImmediateEngagement(
  entriesAfterInput: JournalEntry[],
  options: { newEntryId: string },
): ImmediateEngagementPayload {
  const entriesAfter = eligible(entriesAfterInput);
  const { newEntryId } = options;
  const picked = pickNotice(entriesAfter, newEntryId);
  const followUpId = newId("ifu");

  return {
    id: newId("ieg"),
    entryId: newEntryId,
    generatedAt: new Date().toISOString(),
    noticeKind: picked.kind,
    noticeCategory: IMMEDIATE_NOTICE_CATEGORY[picked.kind],
    noticeDetail: picked.detail,
    followUpId,
    followUpQuestion: IMMEDIATE_FOLLOWUP_BY_KIND[picked.kind],
  };
}

export { IMMEDIATE_ENGAGEMENT_HEADING };
