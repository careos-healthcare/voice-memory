"use client";

import {
  EVIDENCE_QUALITY_COPY,
  subtleEvidenceQualityLabel,
} from "@/lib/blind-spots/a-tier-prioritization";
import type { InsightIngredientProfile } from "@/types/insight-ingredient-optimizer";

interface EvidenceQualityBadgeProps {
  profile?: InsightIngredientProfile;
  className?: string;
}

/**
 * Subtle evidence-quality tier — never shows raw optimizer score or D-tier label.
 */
export function EvidenceQualityBadge({ profile, className = "" }: EvidenceQualityBadgeProps) {
  if (!profile) return null;
  const label = subtleEvidenceQualityLabel(profile.tier);
  if (!label) return null;

  const tone =
    profile.tier === "a_tier"
      ? "border-emerald-500/20 text-emerald-200/80"
      : profile.tier === "b_tier"
        ? "border-violet-500/20 text-violet-200/70"
        : "border-white/10 text-zinc-500";

  return (
    <p
      className={`inline-flex items-center gap-2 rounded-md border px-2 py-1 text-[10px] uppercase tracking-wider ${tone} ${className}`}
      data-testid="evidence-quality-badge"
      aria-label={`${EVIDENCE_QUALITY_COPY.sectionLabel}: ${label}`}
    >
      <span className="text-zinc-600">{EVIDENCE_QUALITY_COPY.sectionLabel}</span>
      <span>{label}</span>
    </p>
  );
}
