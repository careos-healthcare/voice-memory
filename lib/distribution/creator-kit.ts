import { CreatorStoryBuilder } from "@/lib/distribution/creator-story-builder";
import { buildArchiveShareCards } from "@/lib/distribution/archive-share-cards";
import { readDistributionMoments } from "@/lib/distribution/transformation-moments";
import { readDistributionTestimonials } from "@/lib/distribution/testimonial-store";
import type { CreatorKit } from "@/types/distribution";

const KIT_SIZE = 10;

function padTo<T>(items: T[], fallback: T, size: number): T[] {
  const out = [...items];
  while (out.length < size) out.push(fallback);
  return out.slice(0, size);
}

/** Creator kit — hooks, templates, screenshots, moments from real archive events. */
export function buildCreatorKit(): CreatorKit {
  const moments = readDistributionMoments();
  const testimonials = readDistributionTestimonials();
  const shareCards = buildArchiveShareCards();
  const story = new CreatorStoryBuilder().build();

  const hooks = padTo(
    [
      story.hook,
      "I did not expect my voice notes to form a belief.",
      "My archive noticed something before I did.",
      "I came back and the archive had moved.",
      ...moments.map((m) => m.headline),
    ].filter(Boolean),
    story.hook,
    KIT_SIZE,
  );

  const storyTemplates = padTo(
    [
      new CreatorStoryBuilder().forTikTok(),
      new CreatorStoryBuilder().forInstagram(),
      new CreatorStoryBuilder().forShorts(),
      ...testimonials.map((t) =>
        new CreatorStoryBuilder({ testimonial: t.text }).build().full,
      ),
    ].filter(Boolean),
    story.full,
    KIT_SIZE,
  );

  const screenshotExamples = padTo(
    shareCards.map((c) => c.line),
    "My archive changed its mind.",
    KIT_SIZE,
  );

  const archiveMoments = padTo(
    moments.map((m) => m.headline),
    story.archiveMoment,
    KIT_SIZE,
  );

  return {
    generatedAt: new Date().toISOString(),
    hooks,
    storyTemplates,
    screenshotExamples,
    archiveMoments,
  };
}
