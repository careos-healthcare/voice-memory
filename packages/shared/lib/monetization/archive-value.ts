import { readLastBackupAt } from "@/lib/sync/status-storage";
import { LAUNCH_EVENTS, countLocalEvents } from "@/lib/local-analytics";
import { buildArchiveAttachmentReport } from "@/lib/research/archive-attachment";
import { buildWillingnessSignalsReport } from "@/lib/research/willingness-signals";
import { getMemoryEligibleEntries } from "@/lib/storage";
import type {
  ArchiveValueLine,
  ArchiveValueMoment,
  ArchiveValueMomentKind,
  ArchiveValueReport,
  PremiumSurface,
} from "@/types/monetization-validation";

export const ARCHIVE_VALUE_LINES: Record<ArchiveValueMomentKind, string[]> = {
  encrypted_backup: [
    "Encrypted backup keeps this recoverable.",
    "You can continue this across devices.",
  ],
  export_usage: [
    "Your archive can stay with you.",
    "Some people choose to protect their archive long-term.",
  ],
  restore_usage: [
    "Your archive can stay with you.",
    "Encrypted backup keeps this recoverable.",
  ],
  oldest_revisited: [
    "Some people choose to protect their archive long-term.",
    "Your archive can stay with you.",
  ],
  reopen_chain: [
    "Your archive can stay with you.",
    "Some people choose to protect their archive long-term.",
  ],
  would_miss_archive: [
    "Your archive can stay with you.",
    "Some people choose to protect their archive long-term.",
  ],
  return_after_absence: [
    "You can continue this across devices.",
    "Your archive can stay with you.",
  ],
  restore_after_reinstall: [
    "Encrypted backup keeps this recoverable.",
    "Your archive can stay with you.",
  ],
};

export const ARCHIVE_VALUE_FORBIDDEN = [
  "upgrade now",
  "limited time",
  "don't lose",
  "never lose",
  "unlock your potential",
  "act now",
  "last chance",
  "hurry",
  "subscribe now",
  "fear",
  "productivity",
  "optimize",
  "insights",
  "intelligence",
] as const;

function passesArchiveValueCopy(text: string): boolean {
  const lower = text.toLowerCase();
  return !ARCHIVE_VALUE_FORBIDDEN.some((phrase) => lower.includes(phrase));
}

function moment(
  kind: ArchiveValueMomentKind,
  label: string,
  detail: string,
  strength: number,
  at?: string,
): ArchiveValueMoment {
  return { id: `av-${kind}-${at?.slice(0, 10) ?? "static"}`, kind, label, detail, strength, at };
}

/** Detect archive-value / WTP moments from attachment and behavior. */
export function detectArchiveValueMoments(): ArchiveValueMoment[] {
  const entries = getMemoryEligibleEntries();
  const attachment = buildArchiveAttachmentReport(entries);
  const willingness = buildWillingnessSignalsReport();
  const moments: ArchiveValueMoment[] = [];

  if (readLastBackupAt()) {
    moments.push(
      moment(
        "encrypted_backup",
        "Encrypted backup enabled",
        `Last backup ${readLastBackupAt()}`,
        75,
        readLastBackupAt()!,
      ),
    );
  }

  if (countLocalEvents(LAUNCH_EVENTS.exportUsed) > 0) {
    moments.push(
      moment(
        "export_usage",
        "Archive exported",
        `${countLocalEvents(LAUNCH_EVENTS.exportUsed)} export(s)`,
        72,
      ),
    );
  }

  for (const signal of attachment.signals) {
    if (signal.kind === "oldest_revisited") {
      moments.push(moment("oldest_revisited", signal.label, signal.detail, signal.strength, signal.entryId));
    }
    if (signal.kind === "reopen_chain") {
      moments.push(moment("reopen_chain", signal.label, signal.detail, signal.strength, signal.entryId));
    }
    if (signal.kind === "restore_after_reinstall") {
      moments.push(moment("restore_after_reinstall", signal.label, signal.detail, signal.strength));
    }
  }

  for (const row of willingness.behavioral) {
    if (row.kind === "would_miss_archive") {
      moments.push(moment("would_miss_archive", row.label, row.detail, row.strength, row.at));
    }
    if (row.kind === "revisited_after_absence") {
      moments.push(moment("return_after_absence", row.label, row.detail, row.strength, row.at));
    }
    if (row.kind === "returned_after_failed_sync") {
      moments.push(moment("restore_usage", row.label, row.detail, row.strength, row.at));
    }
    if (row.kind === "enabled_backup") {
      moments.push(moment("encrypted_backup", row.label, row.detail, row.strength, row.at));
    }
    if (row.kind === "exported_archive") {
      moments.push(moment("export_usage", row.label, row.detail, row.strength, row.at));
    }
  }

  const seen = new Set<string>();
  return moments
    .filter((row) => {
      const key = `${row.kind}:${row.detail}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    })
    .sort((a, b) => b.strength - a.strength);
}

function lineForMoment(kind: ArchiveValueMomentKind, surface: PremiumSurface): string | null {
  const options = ARCHIVE_VALUE_LINES[kind];
  const surfaceBias =
    surface === "account" || surface === "restore"
      ? ["encrypted_backup", "restore_usage", "restore_after_reinstall"]
      : ["export_usage", "oldest_revisited", "reopen_chain"];

  if (surfaceBias.includes(kind)) {
    const preferred = options.find((text) => passesArchiveValueCopy(text));
    if (preferred) return preferred;
  }

  for (const text of options) {
    if (passesArchiveValueCopy(text)) return text;
  }

  return null;
}

export function buildArchiveValueReport(surface: PremiumSurface = "archive"): ArchiveValueReport {
  const moments = detectArchiveValueMoments();
  const strongest = moments[0] ?? null;
  const text = strongest ? lineForMoment(strongest.kind, surface) : null;

  return {
    generatedAt: new Date().toISOString(),
    hasData: moments.length > 0,
    moments,
    strongestMoment: strongest,
    suggestedLine: text
      ? {
          id: `line-${strongest!.kind}-${surface}`,
          text,
          momentKind: strongest!.kind,
          surface,
        }
      : null,
  };
}

export function pickArchiveValueLineForSurface(surface: PremiumSurface): ArchiveValueLine | null {
  const report = buildArchiveValueReport(surface);
  return report.suggestedLine;
}
