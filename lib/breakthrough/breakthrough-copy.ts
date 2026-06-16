import type { BreakthroughPromptAnswer, BreakthroughType } from "@/types/breakthrough-tracking";
import type { BreakthroughPromptOffer } from "@/types/breakthrough-tracking";

export const BREAKTHROUGH_PROMPTS: BreakthroughPromptOffer[] = [
  {
    id: "noticed_pattern",
    question: "Did you notice this pattern in real life?",
    surface: "blind_spot",
  },
  {
    id: "insight_changed",
    question: "Did this insight change anything?",
    surface: "blind_spot",
  },
  {
    id: "theory_right",
    question: "Was this theory actually right?",
    surface: "theory",
  },
];

const TYPE_BY_PROMPT_AND_ANSWER: Record<
  string,
  Record<BreakthroughPromptAnswer, BreakthroughType>
> = {
  noticed_pattern: {
    yes: "noticed_pattern",
    not_sure: "caught_it_earlier",
    no: "caught_it_earlier",
  },
  insight_changed: {
    yes: "behavior_changed",
    not_sure: "acted_differently",
    no: "caught_it_earlier",
  },
  theory_right: {
    yes: "theory_was_right",
    not_sure: "acted_differently",
    no: "theory_no_longer_fits",
  },
};

export function resolveBreakthroughType(
  promptId: string,
  answer: BreakthroughPromptAnswer,
): BreakthroughType {
  const map = TYPE_BY_PROMPT_AND_ANSWER[promptId];
  if (map?.[answer]) return map[answer];
  if (answer === "yes") return "behavior_changed";
  if (answer === "not_sure") return "acted_differently";
  return "caught_it_earlier";
}

export function pickBlindSpotBreakthroughPrompt(
  reaction: "surprising" | "uncomfortably_accurate",
  shownIds: string[],
): BreakthroughPromptOffer {
  const prefer =
    reaction === "uncomfortably_accurate" ? "insight_changed" : "noticed_pattern";
  const preferred = BREAKTHROUGH_PROMPTS.find((p) => p.id === prefer && p.surface === "blind_spot");
  if (preferred && !shownIds.includes(preferred.id)) return preferred;

  const fallback = BREAKTHROUGH_PROMPTS.find(
    (p) => p.surface === "blind_spot" && !shownIds.includes(p.id),
  );
  return fallback ?? BREAKTHROUGH_PROMPTS[0]!;
}

export function pickTheoryBreakthroughPrompt(shownIds: string[]): BreakthroughPromptOffer {
  const prompt = BREAKTHROUGH_PROMPTS.find(
    (p) => p.surface === "theory" && !shownIds.includes(p.id),
  );
  return prompt ?? BREAKTHROUGH_PROMPTS[2]!;
}
