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
    title: "What keeps coming back",
    summary: "Themes that keep showing up in your own words.",
    detail:
      "When you speak regularly, certain moods, topics, and phrases return. ArchiveMe brings those repeats forward so you can notice what your days keep circling back to — without labeling or diagnosing you.",
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
    title: "What stayed with you",
    summary: "People, concerns, and goals that persist across entries.",
    detail:
      "Names and worries mentioned more than once become part of your private map. Over time you can see what stayed on your mind between recordings — like a thread through your own timeline.",
  },
  {
    id: "longitudinal_reflection",
    title: "Your story over time",
    summary: "More than today alone.",
    detail:
      "ArchiveMe is built for accumulation. Weekly summaries, search, and exports let you look back across weeks of voice notes and ask what changed, what stayed, and what you might want to name out loud next.",
  },
];

export function getWhyThisMattersTopic(id: string): WhyThisMattersTopic | undefined {
  return WHY_THIS_MATTERS_TOPICS.find((topic) => topic.id === id);
}
