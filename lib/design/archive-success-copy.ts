/**
 * Archive Taste v1 — success states use archive language, not generic SaaS copy.
 */

import type { ReflectionImpactKind } from "@/lib/archive/reflection-impact-receipt";

export const ARCHIVE_SUCCESS_HEADLINE = "Archive updated.";

export const ARCHIVE_SUCCESS_BY_KIND: Record<ReflectionImpactKind, string> = {
  supported_belief: "New evidence supported this belief.",
  challenged_belief: "New evidence challenged this belief.",
  new_life_area: "New life-area evidence added.",
  increased_confidence: "Archive confidence increased.",
  reduced_confidence: "Archive confidence decreased.",
  comparison_point: "Another comparison point for your archive.",
};

/** Disallowed success / completion phrases on archive paths. */
export const ARCHIVE_SUCCESS_BANNED = [
  "Success!",
  "Reflection saved",
  "Reflection processed",
  "Entry captured",
  "Reflection recorded",
] as const;

export function archiveSuccessLine(kind: ReflectionImpactKind): string {
  return `${ARCHIVE_SUCCESS_HEADLINE} ${ARCHIVE_SUCCESS_BY_KIND[kind]}`;
}
