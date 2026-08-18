/** Reject tutorial overload, AI hype, productivity, and therapy framing in onboarding surfaces. */

export const ONBOARDING_BLOCKED_TERMS = [
  "life-changing",
  "game-changer",
  "unlock your potential",
  "self-improvement",
  "self-awareness",
  "productivity",
  "habit stack",
  "AI-powered",
  "powered by AI",
  "therapist",
  "tutorial",
  "step-by-step guide",
  "reflective intelligence",
  "longitudinal memory",
  "emotional archive",
  "memory intelligence",
  "emotional continuity",
  "intelligence layer",
  "what keeps coming back",
  "reflective mirror",
  "gently return",
  "living resurfacing",
  "voice identity",
  "emotional chapter",
  "discover patterns",
  "mindfulness",
  "coaching",
  "growth journey",
  "healing journey",
  "your journey",
  "AI journal",
] as const;

const VAGUE_UNGROUNDED = [
  /\bcontinuity\b(?!\s+across\s+days)/i,
  /\breflective intelligence\b/i,
  /\blongitudinal memory\b/i,
  /\bemotional archive\b/i,
  /\bmemory intelligence\b/i,
  /\bemotional continuity\b/i,
  /\breflective mirror\b/i,
  /\bgently return\b/i,
  /\bgently bring\b/i,
  /\bliving resurfacing\b/i,
  /\bvoice identity\b/i,
  /\bemotional chapter\b/i,
  /\bintelligence layer\b/i,
  /\bwhat keeps coming back\b/i,
  /\brecurring patterns over time\b/i,
  /\bdiscover patterns\b/i,
  /\bself-awareness\b/i,
  /\bmindfulness\b/i,
  /\binsights?\s+summary\b/i,
  /\b(?:healing|growth|inner)\s+journey\b/i,
  /\bcoaching\b(?!\s+plan)/i,
] as const;

export function isOnboardingCopyAllowed(line: string): boolean {
  const trimmed = line.trim();
  if (!trimmed) return false;
  const lower = trimmed.toLowerCase();
  for (const term of ONBOARDING_BLOCKED_TERMS) {
    if (lower.includes(term.toLowerCase())) return false;
  }
  for (const re of VAGUE_UNGROUNDED) {
    if (re.test(trimmed)) return false;
  }
  return true;
}

export function assessOnboardingCopyLine(
  line: string,
  id: string,
): { id: string; allowed: boolean; reason: string | null } {
  if (isOnboardingCopyAllowed(line)) {
    return { id, allowed: true, reason: null };
  }
  const lower = line.toLowerCase();
  for (const term of ONBOARDING_BLOCKED_TERMS) {
    if (lower.includes(term.toLowerCase())) {
      return { id, allowed: false, reason: `blocked term: ${term}` };
    }
  }
  for (const re of VAGUE_UNGROUNDED) {
    if (re.test(line)) {
      return { id, allowed: false, reason: `vague term: ${re.source}` };
    }
  }
  return { id, allowed: false, reason: "restraint" };
}
