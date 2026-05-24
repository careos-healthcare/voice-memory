const MOVIE_TRAILER_RE =
  /\b(everything changed|nothing would be the same|little did (i|you) know|in that moment|the turning point|changed forever)\b/i;
const FAKE_PROFUNDITY_RE =
  /\b(profound|life-changing|transformative|deeply meaningful|true self|inner truth|soul|destiny)\b/i;
const PERFECT_ARC_RE =
  /\b(from darkness to light|finally at peace|complete closure|fully healed|at last i understand)\b/i;
const INTERCHANGEABLE_RE =
  /\b(your journey|this chapter|growth phase|healing era|new beginning|fresh start)\b/i;
const OVERFAMILIAR_RE =
  /\b(you've come so far|look how far|proud of you|brave step|keep going|you've got this)\b/i;

const ANTI_TEMPLATE_PATTERNS: Array<{ id: string; pattern: RegExp; label: string }> = [
  { id: "movie_trailer", pattern: MOVIE_TRAILER_RE, label: "Movie-trailer wisdom" },
  { id: "fake_profundity", pattern: FAKE_PROFUNDITY_RE, label: "Fake profundity" },
  { id: "perfect_arc", pattern: PERFECT_ARC_RE, label: "Too-perfect emotional arc" },
  { id: "interchangeable", pattern: INTERCHANGEABLE_RE, label: "Interchangeable phrasing" },
  { id: "overfamiliar", pattern: OVERFAMILIAR_RE, label: "Emotionally overfamiliar" },
];

export const ANTI_TEMPLATE_WARNING = "This callback may sound generated.";

/** Suppress template-like callbacks — movie-trailer wisdom, fake profundity, perfect arcs. */
export function evaluateAntiTemplate(text: string): {
  suppressed: boolean;
  warning: string | null;
  reasons: string[];
} {
  const reasons: string[] = [];

  for (const { pattern, label } of ANTI_TEMPLATE_PATTERNS) {
    if (pattern.test(text)) reasons.push(label);
  }

  if (text.length > 180 && !/\b(before|after|around|months|weeks)\b/i.test(text)) {
    reasons.push("Long generic note without temporal grounding");
  }

  const suppressed = reasons.length >= 1;
  return {
    suppressed,
    warning: suppressed ? ANTI_TEMPLATE_WARNING : null,
    reasons,
  };
}

export function passesAntiTemplate(text: string): boolean {
  return !evaluateAntiTemplate(text).suppressed;
}

export function scanAntiTemplateViolations(
  texts: Array<{ id: string; text: string }>,
): Array<{ id: string; text: string; warning: string; reasons: string[] }> {
  return texts
    .map((row) => {
      const result = evaluateAntiTemplate(row.text);
      if (!result.suppressed) return null;
      return {
        id: row.id,
        text: row.text.slice(0, 120),
        warning: result.warning ?? ANTI_TEMPLATE_WARNING,
        reasons: result.reasons,
      };
    })
    .filter(Boolean) as Array<{ id: string; text: string; warning: string; reasons: string[] }>;
}
