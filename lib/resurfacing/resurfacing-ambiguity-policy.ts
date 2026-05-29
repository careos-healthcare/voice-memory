import type { ResurfacingEvidence } from "@/types/resurfacing-evidence";
import { hasResurfacingEvidenceAnchors } from "@/lib/resurfacing/resurfacing-evidence";

export interface AmbiguityPolicyInput {
  evidence: ResurfacingEvidence;
  missingTranscript?: boolean;
  quoteLength?: number;
}

export interface AmbiguityPolicyVerdict {
  suppress: boolean;
  forceCautious: boolean;
  reasons: string[];
}

const STRONG_EVIDENCE_SCORE = 52;
const PRONOUN_ONLY_RE = /^(he|she|they|it)\b/i;

/** Regex-based ambiguity — fail safe; does not claim sarcasm detection is solved. */
export function applyAmbiguityFailsafePolicy(
  input: AmbiguityPolicyInput,
): AmbiguityPolicyVerdict {
  const { evidence } = input;
  const reasons: string[] = [];
  let suppress = false;
  let forceCautious = false;

  const weak = evidence.evidenceScore < 42;
  const strong = evidence.evidenceScore >= STRONG_EVIDENCE_SCORE;
  const hasSarcasm = Boolean(evidence.sarcasmSignal);
  const hasVagueness = Boolean(evidence.vaguenessSignal);
  const flat = evidence.vaguenessSignal?.includes("flat") ?? false;
  const missingTranscript = Boolean(input.missingTranscript);
  const quote = evidence.exactQuoteMatches[0] ?? "";
  const pronounOnly =
    quote.length > 0 &&
    quote.length < 28 &&
    PRONOUN_ONLY_RE.test(quote.trim()) &&
    evidence.sharedPeople.length === 0 &&
    evidence.repeatedPhrases.length === 0;

  if (missingTranscript && !hasResurfacingEvidenceAnchors(evidence)) {
    suppress = true;
    reasons.push("missing_transcript_no_anchor");
  }

  if (pronounOnly) {
    suppress = true;
    reasons.push("ambiguous_pronoun_needs_anchor");
  }

  if ((hasSarcasm || hasVagueness) && weak) {
    suppress = true;
    reasons.push("ambiguity_weak_evidence");
  }

  if (hasSarcasm && !strong) {
    suppress = true;
    reasons.push("sarcasm_not_strong_enough");
  } else if (hasSarcasm && strong) {
    forceCautious = true;
    reasons.push("sarcasm_cautious_only");
  }

  if (hasVagueness && strong && !suppress) {
    forceCautious = true;
    reasons.push("vagueness_cautious_only");
  }

  if (flat && weak) {
    suppress = true;
    reasons.push("flat_note_weak");
  } else if (flat && !suppress) {
    forceCautious = true;
    reasons.push("flat_note_cautious");
  }

  if (evidence.contradictionSignal && weak) {
    suppress = true;
    reasons.push("contradiction_weak_evidence");
  }

  return { suppress, forceCautious, reasons };
}
