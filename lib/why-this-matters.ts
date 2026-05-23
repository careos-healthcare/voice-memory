export interface WhyThisMattersTopic {
  id: string;
  title: string;
  summary: string;
  detail: string;
}

/** Plain-language explanations — reflective, not clinical. */
export const WHY_THIS_MATTERS_TOPICS: WhyThisMattersTopic[] = [
  {
    id: "recurring_patterns",
    title: "Recurring patterns",
    summary: "Themes that keep showing up in your own words.",
    detail:
      "When you speak regularly, certain moods, topics, and phrases return. VoiceMemory surfaces those repeats so you can notice what your days keep circling back to — without labeling or diagnosing you.",
  },
  {
    id: "emotional_drift",
    title: "Emotional drift",
    summary: "How intensity and tone shift week to week.",
    detail:
      "A single entry is a snapshot. Over a week or two, averages and comparisons show whether things feel calmer, heavier, or steady. It is a trend line in your language, not a mood score from a clinician.",
  },
  {
    id: "memory_continuity",
    title: "Memory continuity",
    summary: "People, concerns, and goals that persist across entries.",
    detail:
      "Names and worries mentioned more than once become part of your private entity map. Continuity helps you see what stayed on your mind between recordings — like a thread through your own timeline.",
  },
  {
    id: "longitudinal_reflection",
    title: "Longitudinal reflection",
    summary: "Your story over time, not just today.",
    detail:
      "VoiceMemory is built for accumulation. Weekly summaries, search, and exports let you look back across weeks of voice notes and ask what changed, what stayed, and what you might want to name out loud next.",
  },
];

export function getWhyThisMattersTopic(id: string): WhyThisMattersTopic | undefined {
  return WHY_THIS_MATTERS_TOPICS.find((topic) => topic.id === id);
}
