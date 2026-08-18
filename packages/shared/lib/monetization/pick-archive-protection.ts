import {
  pickArchiveValueLineForSurface,
} from "@/lib/monetization/archive-value";
import {
  markPremiumMentionShown,
  shouldShowPremiumSurface,
} from "@/lib/monetization/monetization-restraint";
import { trackPremiumLineSeen } from "@/lib/monetization/monetization-observation";
import { refreshPremiumStateFromBehavior } from "@/lib/monetization/premium-state";
import type { ArchiveValueLine, PremiumSurface } from "@/types/monetization-validation";

/** Pick at most one archive-protection line per session on allowed surfaces. */
export async function pickArchiveProtectionLine(
  surface: PremiumSurface,
): Promise<ArchiveValueLine | null> {
  refreshPremiumStateFromBehavior();

  const allowed = await shouldShowPremiumSurface(surface);
  if (!allowed) return null;

  const line = pickArchiveValueLineForSurface(surface);
  if (!line) return null;

  markPremiumMentionShown();
  trackPremiumLineSeen(surface, line.text);
  return line;
}

export async function pickArchiveProtectionText(surface: PremiumSurface): Promise<string | null> {
  const line = await pickArchiveProtectionLine(surface);
  return line?.text ?? null;
}
