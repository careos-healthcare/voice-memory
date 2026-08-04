import type {
  ArchiveVoiceViolation,
  ArchiveVoiceViolationCategory,
} from "@/types/archive-voice";

/** Archive voice — thoughtful, observational; not coach / cheerleader / therapist. */
export const ARCHIVE_VOICE_PREFERRED = [
  "Your archive is still evaluating this.",
  "New evidence may support this theory.",
  "This theory may be changing.",
  "Recent saved moments point in a different direction.",
] as const;

export const ARCHIVE_VOICE_AVOID_EXAMPLES = [
  "Great job",
  "You are growing",
  "You should",
  "Keep going",
  "Proud of you",
  "Healing",
  "Transformation",
] as const;

export const ARCHIVE_VOICE_FORBIDDEN: Record<
  ArchiveVoiceViolationCategory,
  readonly RegExp[]
> = {
  coaching: [
    /\byou should\b/i,
    /\byou must\b/i,
    /\byou need to\b/i,
    /\btry to\b/i,
    /\bconsider trying\b/i,
    /\bbe kind to yourself\b/i,
    /\b(?:life\s+)?coach(?:ing)?\b/i,
    /\bCBT\b/,
    /\bcognitive behavioral\b/i,
    /\bi recommend\b/i,
  ],
  motivational: [
    /\bgreat job\b/i,
    /\byou are growing\b/i,
    /\byou'?re growing\b/i,
    /\bkeep going\b/i,
    /\bproud of you\b/i,
    /\byou'?ve got this\b/i,
    /\blook how far\b/i,
    /\bbrave step\b/i,
    /\bcelebrate\b/i,
    /\bamazing progress\b/i,
  ],
  therapy: [
    /\bhealing journey\b/i,
    /\binner work\b/i,
    /\bhold space\b/i,
    /\bunpack\b/i,
    /\bself-care\b/i,
    /\bwellness\b/i,
    /\btransformation\b/i,
    /\btransformative\b/i,
    /\b(?:best|better)\s+self\b/i,
    /\btherapist\b/i,
    /\bcounsel(?:or|ling)\b/i,
    /\bdiagnos(?:is|e)\b/i,
    /\bdisorder\b/i,
    /\bpatholog\b/i,
    /\bclinical\b/i,
    /\bmeditat(?:e|ion)\b/i,
    /\btrauma\b/i,
  ],
};

/** Standalone therapy mention — allowed in disclaimers ("not therapy"). */
export const ARCHIVE_VOICE_THERAPY_MENTION = /\btherapy\b/i;

export const ARCHIVE_VOICE_FORBIDDEN_UNIFIED = new RegExp(
  Object.values(ARCHIVE_VOICE_FORBIDDEN)
    .flat()
    .map((re) => `(?:${re.source})`)
    .join("|"),
  "i",
);

function isRegexGuardLine(line: string): boolean {
  const trimmed = line.trim();
  if (
    /^(?:export\s+)?const\s+\w*(?:FORBIDDEN|_RE|CERTAINTY|ARCHIVE_VOICE)/.test(trimmed)
  ) {
    return true;
  }
  if (/=\/\\b\(/i.test(trimmed) && /\/i[,;]?\s*$/.test(trimmed)) return true;
  if (/^\/\\b\(/i.test(trimmed) && /\/i[,;]?\s*$/.test(trimmed)) return true;
  return false;
}

export function isArchiveVoiceExemptLine(line: string): boolean {
  const trimmed = line.trim();
  if (!trimmed) return true;
  if (isRegexGuardLine(trimmed)) return true;
  if (/ARCHIVE_VOICE_FORBIDDEN|FORBIDDEN_\w+/.test(trimmed) && /\/\\b|\\b\(/.test(trimmed)) {
    return true;
  }
  if (/^\s*\/\/|^\s*\*|^\s*\/\*/.test(trimmed)) return true;
  if (/\bnot\s+therapy\b/i.test(trimmed)) return true;
  if (/\bnot\s+advice\b/i.test(trimmed)) return true;
  if (/\bnot\s+a\s+diagnosis\b/i.test(trimmed)) return true;
  if (/\bNO\s+(?:advice|motivational|therapy)\b/i.test(trimmed)) return true;
  if (/\bwithout\s+hurting\b/i.test(trimmed)) return true;
  return false;
}

function therapyMatchAllowed(line: string, match: string): boolean {
  if (!ARCHIVE_VOICE_THERAPY_MENTION.test(match)) return true;
  return /\bnot\s+therapy\b/i.test(line);
}

export function scanArchiveVoiceLine(
  line: string,
  lineNumber: number,
  file: string,
): ArchiveVoiceViolation[] {
  if (isArchiveVoiceExemptLine(line)) return [];

  const violations: ArchiveVoiceViolation[] = [];
  for (const [category, patterns] of Object.entries(ARCHIVE_VOICE_FORBIDDEN) as [
    ArchiveVoiceViolationCategory,
    readonly RegExp[],
  ][]) {
    for (const pattern of patterns) {
      const match = line.match(pattern);
      if (!match?.[0]) continue;
      if (category === "therapy" && !therapyMatchAllowed(line, match[0])) continue;
      violations.push({
        file,
        line: lineNumber,
        category,
        match: match[0],
        excerpt: line.trim().slice(0, 160),
      });
      break;
    }
  }
  return violations;
}

export function scanArchiveVoiceSource(
  source: string,
  file: string,
): ArchiveVoiceViolation[] {
  const lines = source.split("\n");
  const all: ArchiveVoiceViolation[] = [];
  for (let i = 0; i < lines.length; i++) {
    all.push(...scanArchiveVoiceLine(lines[i] ?? "", i + 1, file));
  }
  return all;
}

export const ARCHIVE_VOICE_PREFERRED_SIGNALS = [
  "archive is still",
  "still evaluating",
  "still weighing",
  "new evidence may",
  "theory may be changing",
  "may be changing",
  "point in a different direction",
  "working theory",
  "your archive",
] as const;

export function findPreferredSignalsInSource(source: string): string[] {
  const lower = source.toLowerCase();
  return ARCHIVE_VOICE_PREFERRED_SIGNALS.filter((signal) => lower.includes(signal));
}
