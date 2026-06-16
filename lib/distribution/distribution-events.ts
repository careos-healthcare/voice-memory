import { trackLocalEvent } from "@/lib/local-analytics";
import type { TransformationMomentType } from "@/types/distribution";

export const DISTRIBUTION_EVENTS = {
  shareCardShown: "distribution_share_card_shown",
  shareCardCopied: "distribution_share_card_copied",
  shareCardExported: "distribution_share_card_exported",
  shareArchivePromptSeen: "distribution_share_archive_seen",
  shareArchiveClicked: "distribution_share_archive_clicked",
  testimonialPromptSeen: "distribution_testimonial_prompt_seen",
  testimonialSubmitted: "distribution_testimonial_submitted",
  creatorStoryCopied: "distribution_creator_story_copied",
  creatorKitOpened: "distribution_creator_kit_opened",
} as const;

export function trackDistributionShareShown(meta?: {
  momentType?: TransformationMomentType;
  variant?: string;
}): void {
  trackLocalEvent(DISTRIBUTION_EVENTS.shareCardShown, meta);
}

export function trackDistributionShareCopied(meta?: {
  momentType?: TransformationMomentType;
}): void {
  trackLocalEvent(DISTRIBUTION_EVENTS.shareCardCopied, meta);
}

export function trackDistributionShareExported(meta?: {
  momentType?: TransformationMomentType;
}): void {
  trackLocalEvent(DISTRIBUTION_EVENTS.shareCardExported, meta);
}

export function trackShareArchivePromptSeen(meta?: {
  trigger?: TransformationMomentType;
}): void {
  trackLocalEvent(DISTRIBUTION_EVENTS.shareArchivePromptSeen, meta);
}

export function trackShareArchiveClicked(meta?: {
  trigger?: TransformationMomentType;
}): void {
  trackLocalEvent(DISTRIBUTION_EVENTS.shareArchiveClicked, meta);
}

export function trackTestimonialPromptSeen(meta?: {
  momentType?: TransformationMomentType;
}): void {
  trackLocalEvent(DISTRIBUTION_EVENTS.testimonialPromptSeen, meta);
}

export function trackTestimonialSubmitted(meta?: {
  momentType?: TransformationMomentType;
  rating?: string;
}): void {
  trackLocalEvent(DISTRIBUTION_EVENTS.testimonialSubmitted, meta);
}

export function trackCreatorStoryCopied(meta?: { format?: string }): void {
  trackLocalEvent(DISTRIBUTION_EVENTS.creatorStoryCopied, meta);
}

export function trackCreatorKitOpened(): void {
  trackLocalEvent(DISTRIBUTION_EVENTS.creatorKitOpened, {});
}
