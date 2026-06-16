import { readDistributionTestimonials } from "@/lib/distribution/testimonial-store";
import { readDistributionMoments } from "@/lib/distribution/transformation-moments";
import { getArchiveProofStories } from "@/lib/social-proof/archive-proof-stories";

export type ProofWallItemKind = "testimonial" | "archive_moment" | "tester_quote";

export type ProofWallItem = {
  id: string;
  kind: ProofWallItemKind;
  text: string;
  label?: string;
};

export type ProofWallData = {
  label: string;
  items: ProofWallItem[];
  hasRealProof: boolean;
};

/** Landing proof — only real testimonials, archive moments, and stored tester quotes. */
export function buildProofWall(): ProofWallData {
  const items: ProofWallItem[] = [];

  for (const testimonial of readDistributionTestimonials()) {
    if (!testimonial.text.trim()) continue;
    items.push({
      id: testimonial.id,
      kind: "testimonial",
      text: testimonial.text,
      label: "From someone using ArchiveMe",
    });
  }

  for (const moment of readDistributionMoments()) {
    if (!moment.headline.trim()) continue;
    items.push({
      id: moment.id,
      kind: "archive_moment",
      text: moment.headline,
      label: "Archive moment",
    });
  }

  const stories = getArchiveProofStories();
  for (const story of stories.stories) {
    if (!story.quote.trim()) continue;
    items.push({
      id: story.id,
      kind: "tester_quote",
      text: story.quote,
      label: stories.label,
    });
  }

  return {
    label: "What people notice",
    items: items.slice(0, 12),
    hasRealProof: items.some(
      (row) => row.kind === "testimonial" || row.kind === "archive_moment",
    ),
  };
}
