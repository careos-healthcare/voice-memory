import type { CallbackReviewKind, RewriteCandidateFlag } from "@/types/callback-quality-review";

const GENERIC_PHRASES: RegExp[] = [
  /\bmay feel different\b/i,
  /\bcame back softly\b/i,
  /\bthis changed over time\b/i,
  /\bhas been quiet for a while\b/i,
  /\bbeginning to mean something\b/i,
  /\bkept coming back to a few things\b/i,
  /\bmean something different\b/i,
  /\bmore personal\b/i,
  /\brecurring pattern\b/i,
  /\bdominant theme\b/i,
  /\bfirst memory\b/i,
  /\bthreads can start appearing\b/i,
  /\bchanges may begin to surface\b/i,
  /\bbecame clearer\b/i,
  /\bthis was the first calmer version\b/i,
  /\bthis stopped appearing\b/i,
  /\bwhen the wording changed\b/i,
];

const TEMPLATE_OPENERS: RegExp[] = [
  /^This was /i,
  /^This has been /i,
  /^An older reflection /i,
  /^You mentioned /i,
  /^There is more /i,
  /^More of your reflections /i,
  /^Your archive has /i,
  /^Older reflections are /i,
  /^VoiceMemory /i,
];

const UNIVERSAL_PHRASES: RegExp[] = [
  /^This came back softly\.?$/i,
  /^This has been quiet for a while\.?$/i,
  /^An older reflection may feel different now\.?$/i,
  /^This shifted over time\.?$/i,
  /^A quieter version of the same thing\.?$/i,
  /^I forgot I used to sound like this\.?$/i,
];

function normalize(text: string): string {
  return text.toLowerCase().replace(/[^\w\s]/g, " ").replace(/\s+/g, " ").trim();
}

function quoteSimilarity(a: string, b: string): number {
  const left = new Set(normalize(a).split(" ").filter(Boolean));
  const right = new Set(normalize(b).split(" ").filter(Boolean));
  if (left.size === 0 || right.size === 0) return 0;
  let overlap = 0;
  for (const token of left) {
    if (right.has(token)) overlap += 1;
  }
  return overlap / Math.max(left.size, right.size);
}

export function detectRewriteCandidateFlags(input: {
  text: string;
  beforeQuote?: string;
  afterQuote?: string;
  kind?: CallbackReviewKind;
}): RewriteCandidateFlag[] {
  const flags: RewriteCandidateFlag[] = [];
  const text = input.text.trim();
  if (!text) return flags;

  if (GENERIC_PHRASES.some((pattern) => pattern.test(text))) {
    flags.push("generic_wording");
  }

  if (TEMPLATE_OPENERS.some((pattern) => pattern.test(text))) {
    flags.push("templated");
  }

  if (text.length > 180 || text.split(/[.!?]/).filter((part) => part.trim()).length > 3) {
    flags.push("over_explains");
  }

  const hasQuotes = Boolean(input.beforeQuote?.trim() || input.afterQuote?.trim());
  const hasNamedDetail = /\b(mum|dad|mother|father|Sarah|work|home)\b/i.test(text);
  if (!hasQuotes && text.length < 42 && !hasNamedDetail) {
    flags.push("lacks_specificity");
  }

  if (
    input.beforeQuote?.trim() &&
    input.afterQuote?.trim() &&
    quoteSimilarity(input.beforeQuote, input.afterQuote) >= 0.82
  ) {
    flags.push("lacks_emotional_contrast");
  }

  if (UNIVERSAL_PHRASES.some((pattern) => pattern.test(text))) {
    flags.push("could_apply_to_many");
  }

  if (
    input.kind === "continuity_depth" ||
    input.kind === "archive_growth" ||
    input.kind === "memory_reminder"
  ) {
    if (!flags.includes("could_apply_to_many") && !hasQuotes) {
      flags.push("could_apply_to_many");
    }
  }

  return [...new Set(flags)];
}
