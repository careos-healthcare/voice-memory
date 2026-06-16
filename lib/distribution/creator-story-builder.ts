import { latestDistributionMoment } from "@/lib/distribution/transformation-moments";
import type {
  CreatorStory,
  CreatorStoryFormat,
  DistributionWorthyMoment,
} from "@/types/distribution";

const DEFAULT_HOOK = "I thought I was recording voice notes.";
const DEFAULT_MOMENT =
  "Three weeks later my archive changed its view of me.";
const DEFAULT_RESULT = "That surprised me.";

export class CreatorStoryBuilder {
  private readonly moment: DistributionWorthyMoment | null;
  private readonly testimonialLine: string | null;

  constructor(options?: {
    moment?: DistributionWorthyMoment | null;
    testimonial?: string | null;
  }) {
    this.moment = options?.moment ?? latestDistributionMoment();
    this.testimonialLine = options?.testimonial?.trim() || null;
  }

  build(): CreatorStory {
    const hook = DEFAULT_HOOK;
    const archiveMoment = this.moment?.headline ?? DEFAULT_MOMENT;
    const result = this.testimonialLine ?? DEFAULT_RESULT;
    const full = `${hook}\n\n${archiveMoment}\n\n${result}`;
    return { hook, archiveMoment, result, full };
  }

  forTikTok(): string {
    const story = this.build();
    return [story.hook, story.archiveMoment, story.result]
      .map((line) => line.trim())
      .filter(Boolean)
      .join("\n");
  }

  forInstagram(): string {
    const story = this.build();
    return `${story.hook}\n\n${story.archiveMoment}\n\n— ${story.result}`;
  }

  forShorts(): string {
    const story = this.build();
    return `${story.hook} ${story.archiveMoment} ${story.result}`;
  }

  export(format: CreatorStoryFormat): string {
    switch (format) {
      case "tiktok":
        return this.forTikTok();
      case "instagram":
        return this.forInstagram();
      case "shorts":
        return this.forShorts();
      default:
        return this.build().full;
    }
  }
}
