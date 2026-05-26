import type { ThinkingOutLoudSignals } from "@/types/clarity";

interface CueRule {
  label: string;
  re: RegExp;
  weight: number;
  flags: {
    conflict?: boolean;
    uncertainty?: boolean;
    avoided?: boolean;
    repeated?: boolean;
  };
}

const CUE_RULES: CueRule[] = [
  { label: "argument", re: /\b(argument|argued|arguing|fight|fighting|yelled|shouting)\b/i, weight: 10, flags: { conflict: true } },
  { label: "conflict", re: /\b(conflict|confrontation|blew up|walked out|stormed)\b/i, weight: 10, flags: { conflict: true } },
  { label: "upset", re: /\b(upset|hurt|hurting|cried|crying|furious|rage)\b/i, weight: 8, flags: { conflict: true, uncertainty: true } },
  { label: "misunderstood", re: /\b(misunderstood|misread|took it the wrong way|didn'?t hear me)\b/i, weight: 12, flags: { conflict: true, repeated: true } },
  { label: "disrespected", re: /\b(disrespected|dismissed|ignored me|talked over)\b/i, weight: 12, flags: { conflict: true } },
  { label: "dont_know", re: /\b(i don'?t know what to do|not sure what to do|no idea what to)\b/i, weight: 14, flags: { uncertainty: true } },
  { label: "keep_thinking", re: /\b(i keep thinking|can'?t stop thinking|going over it|replay(?:ing)?)\b/i, weight: 10, flags: { repeated: true, uncertainty: true } },
  { label: "avoided_saying", re: /\b(i avoided saying|didn'?t say|held back|bit my tongue|wanted to say)\b/i, weight: 14, flags: { avoided: true } },
  { label: "wish_said", re: /\b(i wish i said|should have said|wish i'?d said)\b/i, weight: 12, flags: { avoided: true } },
  { label: "they_said", re: /\b(they said|she said|he said|you said|i said)\b/i, weight: 6, flags: { conflict: true } },
  { label: "wrong", re: /\b(i was wrong|they were wrong|my fault|their fault)\b/i, weight: 8, flags: { conflict: true } },
  { label: "guilty", re: /\b(i feel guilty|my guilt|ashamed)\b/i, weight: 10, flags: { uncertainty: true } },
  { label: "angry", re: /\b(i feel angry|so angry|still angry)\b/i, weight: 10, flags: { conflict: true } },
  { label: "not_sure", re: /\b(i'?m not sure|unsure|uncertain|confused about)\b/i, weight: 10, flags: { uncertainty: true } },
  { label: "need_clarity", re: /\b(need clarity|need to understand|make sense of)\b/i, weight: 12, flags: { uncertainty: true } },
];

const MIN_TRANSCRIPT_LEN = 40;
const SHOW_CONFIDENCE = 48;

function emptySignals(): ThinkingOutLoudSignals {
  return {
    conflictLikely: false,
    uncertaintyLikely: false,
    avoidedSpeechLikely: false,
    repeatedThoughtLikely: false,
    confidence: 0,
    matchedPhrases: [],
  };
}

/** Conservative detection — conflict / uncertainty reflections only. */
export function detectThinkingOutLoudSignals(transcript: string): ThinkingOutLoudSignals {
  const text = transcript.trim();
  if (text.length < MIN_TRANSCRIPT_LEN) return emptySignals();

  let score = 0;
  let conflictScore = 0;
  let uncertaintyScore = 0;
  let avoidedScore = 0;
  let repeatedScore = 0;
  const matchedPhrases: string[] = [];

  for (const rule of CUE_RULES) {
    const match = text.match(rule.re);
    if (!match) continue;
    const phrase = match[0].trim().slice(0, 80);
    if (!matchedPhrases.includes(phrase)) matchedPhrases.push(phrase);
    score += rule.weight;
    if (rule.flags.conflict) conflictScore += rule.weight;
    if (rule.flags.uncertainty) uncertaintyScore += rule.weight;
    if (rule.flags.avoided) avoidedScore += rule.weight;
    if (rule.flags.repeated) repeatedScore += rule.weight;
  }

  const confidence = Math.min(100, score);
  return {
    conflictLikely: conflictScore >= 10,
    uncertaintyLikely: uncertaintyScore >= 10,
    avoidedSpeechLikely: avoidedScore >= 12,
    repeatedThoughtLikely: repeatedScore >= 10,
    confidence,
    matchedPhrases: matchedPhrases.slice(0, 8),
  };
}

export function qualifiesForClarityPrompt(signals: ThinkingOutLoudSignals): boolean {
  if (signals.confidence < SHOW_CONFIDENCE) return false;
  if (signals.conflictLikely && signals.uncertaintyLikely) return true;
  if (signals.conflictLikely && (signals.avoidedSpeechLikely || signals.repeatedThoughtLikely)) {
    return true;
  }
  if (signals.uncertaintyLikely && signals.repeatedThoughtLikely) return true;
  if (signals.uncertaintyLikely && signals.avoidedSpeechLikely) return true;
  return false;
}
