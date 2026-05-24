import {
  FORBIDDEN_ABSTRACT_PHRASES,
  PREFERRED_ACQUISITION_WORDS,
  PLAY_STORE_KEYWORDS,
  SCREENSHOT_SETS,
  type ScreenshotSetId,
} from "@/lib/marketing/acquisition-copy";

const MAX_SCREENSHOT_WORDS = 7;

export interface AcquisitionPhraseHit {
  phrase: string;
  where: string;
}

export interface ClarityCheckRow {
  text: string;
  source: string;
  wordCount: number;
  passesWordLimit: boolean;
  preferredHits: string[];
  forbiddenHits: string[];
  emotionalClarityScore: number;
  normalUserWouldUnderstand: boolean;
  notes: string[];
}

export interface KeywordCoverageRow {
  keyword: string;
  inShortDescription: boolean;
  inFullDescription: boolean;
  inScreenshotSets: boolean;
  covered: boolean;
}

function normalize(text: string): string {
  return text.toLowerCase();
}

export function findForbiddenAbstractPhrases(text: string, source = "copy"): AcquisitionPhraseHit[] {
  const lower = normalize(text);
  return FORBIDDEN_ABSTRACT_PHRASES.filter((phrase) => lower.includes(phrase.toLowerCase())).map(
    (phrase) => ({ phrase, where: source }),
  );
}

export function findPreferredWordHits(text: string): string[] {
  const lower = normalize(text);
  return PREFERRED_ACQUISITION_WORDS.filter((word) => lower.includes(word.toLowerCase()));
}

export function countWords(text: string): number {
  return text.trim().split(/\s+/).filter(Boolean).length;
}

export function scoreEmotionalClarity(text: string): number {
  const preferred = findPreferredWordHits(text).length;
  const forbidden = findForbiddenAbstractPhrases(text).length;
  const words = countWords(text);
  const lengthPenalty = words > 18 ? Math.min(20, (words - 18) * 2) : 0;
  const jargonPenalty = forbidden * 18;
  const plainBonus = preferred * 8;
  const shortBonus = words <= 7 ? 10 : words <= 12 ? 5 : 0;
  return Math.max(0, Math.min(100, 42 + plainBonus + shortBonus - lengthPenalty - jargonPenalty));
}

export function wouldNormalUserUnderstand(text: string): { ok: boolean; notes: string[] } {
  const notes: string[] = [];
  const forbidden = findForbiddenAbstractPhrases(text);
  if (forbidden.length > 0) {
    notes.push(`Uses abstract phrasing: ${forbidden.map((hit) => hit.phrase).join(", ")}`);
  }
  const words = countWords(text);
  if (words > MAX_SCREENSHOT_WORDS) {
    notes.push(`Headline has ${words} words (max ${MAX_SCREENSHOT_WORDS})`);
  }
  if (/\b(engine|intelligence|graph|longitudinal|cognitive)\b/i.test(text)) {
    notes.push("Contains technical or clinical wording");
  }
  if (findPreferredWordHits(text).length === 0 && words <= 14) {
    notes.push("No plain-language anchor (private, voice, revisit, hear yourself)");
  }
  return { ok: notes.length === 0, notes };
}

export function assessCopyLine(text: string, source: string): ClarityCheckRow {
  const wordCount = countWords(text);
  const understand = wouldNormalUserUnderstand(text);
  return {
    text,
    source,
    wordCount,
    passesWordLimit: wordCount <= MAX_SCREENSHOT_WORDS,
    preferredHits: findPreferredWordHits(text),
    forbiddenHits: findForbiddenAbstractPhrases(text).map((hit) => hit.phrase),
    emotionalClarityScore: scoreEmotionalClarity(text),
    normalUserWouldUnderstand: understand.ok,
    notes: understand.notes,
  };
}

export function buildKeywordCoverage(
  shortDescription: string,
  fullDescription: string,
  screenshotText: string,
): KeywordCoverageRow[] {
  const short = normalize(shortDescription);
  const full = normalize(fullDescription);
  const shots = normalize(screenshotText);

  return PLAY_STORE_KEYWORDS.map((keyword) => {
    const key = keyword.toLowerCase();
    const inShortDescription = short.includes(key);
    const inFullDescription = full.includes(key);
    const inScreenshotSets = shots.includes(key);
    return {
      keyword,
      inShortDescription,
      inFullDescription,
      inScreenshotSets,
      covered: inShortDescription || inFullDescription || inScreenshotSets,
    };
  });
}

export function validateScreenshotSet(setId: ScreenshotSetId): ClarityCheckRow[] {
  const set = SCREENSHOT_SETS.find((row) => row.id === setId);
  if (!set) return [];
  return set.headlines.map((headline) => assessCopyLine(headline, `screenshot:${setId}`));
}

export function allScreenshotHeadlinesText(): string {
  return SCREENSHOT_SETS.flatMap((set) => set.headlines).join("\n");
}

export const ACQUISITION_RESTRAINT_RULES = {
  maxScreenshotWords: MAX_SCREENSHOT_WORDS,
  maxScreensPerSet: 6,
  forbiddenPhrases: [...FORBIDDEN_ABSTRACT_PHRASES],
  preferredWords: [...PREFERRED_ACQUISITION_WORDS],
} as const;
